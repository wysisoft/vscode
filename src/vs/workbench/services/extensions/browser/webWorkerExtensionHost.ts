/*---------------------------------------------------------------------------------------------
 *  Copyright (c) Microsoft Corporation. All rights reserved.
 *  Licensed under the MIT License. See License.txt in the project root for license information.
 *--------------------------------------------------------------------------------------------*/

import * as dom from '../../../../base/browser/dom.js';
import { parentOriginHash } from '../../../../base/browser/iframe.js';
import { mainWindow } from '../../../../base/browser/window.js';
import { Barrier } from '../../../../base/common/async.js';
import { VSBuffer } from '../../../../base/common/buffer.js';
import { canceled, onUnexpectedError } from '../../../../base/common/errors.js';
import { Emitter, Event } from '../../../../base/common/event.js';
import { Disposable, toDisposable } from '../../../../base/common/lifecycle.js';
import { AppResourcePath, COI, FileAccess } from '../../../../base/common/network.js';
import * as platform from '../../../../base/common/platform.js';
import { joinPath } from '../../../../base/common/resources.js';
import { URI } from '../../../../base/common/uri.js';
import { generateUuid } from '../../../../base/common/uuid.js';
import { IMessagePassingProtocol } from '../../../../base/parts/ipc/common/ipc.js';
import { getNLSLanguage, getNLSMessages } from '../../../../nls.js';
import { ILabelService } from '../../../../platform/label/common/label.js';
import { ILayoutService } from '../../../../platform/layout/browser/layoutService.js';
import { ILogService, ILoggerService } from '../../../../platform/log/common/log.js';
import { IProductService } from '../../../../platform/product/common/productService.js';
import { IStorageService, StorageScope, StorageTarget } from '../../../../platform/storage/common/storage.js';
import { ITelemetryService } from '../../../../platform/telemetry/common/telemetry.js';
import { isLoggingOnly } from '../../../../platform/telemetry/common/telemetryUtils.js';
import { IUserDataProfilesService } from '../../../../platform/userDataProfile/common/userDataProfile.js';
import { WebWorkerDescriptor } from '../../../../platform/webWorker/browser/webWorkerDescriptor.js';
import { IWebWorkerService } from '../../../../platform/webWorker/browser/webWorkerService.js';
import { IWorkspaceContextService, WorkbenchState } from '../../../../platform/workspace/common/workspace.js';
import { IBrowserWorkbenchEnvironmentService } from '../../environment/browser/environmentService.js';
import { IDefaultLogLevelsService } from '../../log/common/defaultLogLevels.js';
import { ExtensionHostExitCode, IExtensionHostInitData, MessageType, UIKind, createMessageOfType, isMessageOfType } from '../common/extensionHostProtocol.js';
import { LocalWebWorkerRunningLocation } from '../common/extensionRunningLocation.js';
import { ExtensionHostExtensions, ExtensionHostStartup, IExtensionHost } from '../common/extensions.js';

class ClientState {
	clientId;
	mainProcess: any;
	fs: any;
	promiseId = 0;
	promises = new Map();
	async startMainProcess(nodepod: any) {
		this.fs = nodepod.fs;
		nodepod.fs.writeFile('/tmp/server.js', `
	const readline = require('readline');
	const child_process = require('child_process');

    const rl = readline.createInterface({
      input: process.stdin,
	  terminal: false
    });

    rl.on('line', (line) => {
      let req;
      try {
        req = JSON.parse(line);
      } catch {
        process.stderr.write(JSON.stringify({error: 'bad json'}) + '\\n');
        return;
      }

      const response = { id: req.id };

      if (req.type === 'process') {
        response.result = {
          env: process.env,
          noDeprecation: process.noDeprecation,
          throwDeprecation: process.throwDeprecation,
          traceDeprecation: process.traceDeprecation,
		  type: process.type,
		  stderr: {
		 	fd: process.stderr.fd,
		  },
		  arch: process.arch,
		  argv: process.argv,
        };
      }
	if (req.type === 'child_process.spawn') {
		const spawnResult = child_process.spawn(req.params.command, req.params.args, req.params.options);
		response.result = {
			pid: spawnResult.pid,
			connected: spawnResult.connected,
			killed: spawnResult.killed,
			exitCode: spawnResult.exitCode,
			signalCode: spawnResult.signalCode,
		};
	}
	if (req.type === 'child_process.execFile') {
		const execFileResult = child_process.execFile(req.params.file, req.params.args, req.params.options);
		response.result = {
			pid: execFileResult.pid,
			connected: execFileResult.connected,
			killed: execFileResult.killed,
			exitCode: execFileResult.exitCode,
			signalCode: execFileResult.signalCode,
		};
	}
	if (req.type === 'child_process.execFileSync') {
		const execFileSyncResult = child_process.execFileSync(req.params.file, req.params.args, req.params.options);
		response.result = {
			pid: execFileSyncResult.pid,
			connected: execFileSyncResult.connected,
			killed: execFileSyncResult.killed,
			exitCode: execFileSyncResult.exitCode,
			signalCode: execFileSyncResult.signalCode,
		};
	}
	if (req.type === 'child_process.execSync') {
		const execSyncResult = child_process.execSync(req.params.command, req.params.options);
		response.result = {
			pid: execSyncResult.pid,
			connected: execSyncResult.connected,
			killed: execSyncResult.killed,
			exitCode: execSyncResult.exitCode,
			signalCode: execSyncResult.signalCode,
		};
	}
	if (req.type === 'readline.createInterface') {
		const createInterfaceResult = readline.createInterface(req.params.options);
		response.result = {
			terminal: createInterfaceResult.terminal,
			line: createInterfaceResult.line,
			cursor: createInterfaceResult.cursor,
			history: createInterfaceResult.history
		};
	}

      process.stdout.write(JSON.stringify(response) + '\\n');
    });`);

		this.mainProcess = await nodepod.spawn('node /tmp/server.js');

		eval("debugger;");

		let lineBuffer = '';
		this.mainProcess.on('output', (chunk: any) => {
			debugger;
			lineBuffer += chunk;
			const lines = lineBuffer.split('\n');
			lineBuffer = lines.pop() || ''; // keep incomplete tail
			for (const line of lines) {
				if (!line.trim())
					continue;
				const msg = JSON.parse(line);
				if (msg.id !== undefined) {
					this.promises.get(msg.id)?.resolve(msg.result);
					this.promises.delete(msg.id);
				}
			}
		});
	}
	// --- send helper (returns a Promise) ---
	send(req: any) {
		const id = ++this.promiseId;
		return new Promise((resolve) => {
			this.promises.set(id, { resolve });
			this.mainProcess?.write(JSON.stringify({ id, ...req }) + '\n');
		});
	}
	constructor(clientId: string) {
		this.clientId = clientId;
		this.mainProcess = null;
		this.promiseId = 0;
		this.promises = new Map();
	}
}

const nodepodClientPrefix = "nodepodClient:";
const clients = new Map();


export interface IWebWorkerExtensionHostInitData {
	readonly extensions: ExtensionHostExtensions;
}

export interface IWebWorkerExtensionHostDataProvider {
	getInitData(): Promise<IWebWorkerExtensionHostInitData>;
}

export class WebWorkerExtensionHost extends Disposable implements IExtensionHost {

	public readonly pid = null;
	public readonly remoteAuthority = null;
	public extensions: ExtensionHostExtensions | null = null;

	private readonly _onDidExit = this._register(new Emitter<[number, string | null]>());
	public readonly onExit: Event<[number, string | null]> = this._onDidExit.event;

	private _isTerminating: boolean;
	private _protocolPromise: Promise<IMessagePassingProtocol> | null;
	private _protocol: IMessagePassingProtocol | null;

	private readonly _extensionHostLogsLocation: URI;

	constructor(
		public readonly runningLocation: LocalWebWorkerRunningLocation,
		public readonly startup: ExtensionHostStartup,
		private readonly _initDataProvider: IWebWorkerExtensionHostDataProvider,
		@ITelemetryService private readonly _telemetryService: ITelemetryService,
		@IWorkspaceContextService private readonly _contextService: IWorkspaceContextService,
		@ILabelService private readonly _labelService: ILabelService,
		@ILogService private readonly _logService: ILogService,
		@ILoggerService private readonly _loggerService: ILoggerService,
		@IBrowserWorkbenchEnvironmentService private readonly _environmentService: IBrowserWorkbenchEnvironmentService,
		@IUserDataProfilesService private readonly _userDataProfilesService: IUserDataProfilesService,
		@IProductService private readonly _productService: IProductService,
		@ILayoutService private readonly _layoutService: ILayoutService,
		@IStorageService private readonly _storageService: IStorageService,
		@IWebWorkerService private readonly _webWorkerService: IWebWorkerService,
		@IDefaultLogLevelsService private readonly _defaultLogLevelsService: IDefaultLogLevelsService,
	) {
		super();
		this._isTerminating = false;
		this._protocolPromise = null;
		this._protocol = null;
		this._extensionHostLogsLocation = joinPath(this._environmentService.extHostLogsPath, 'webWorker');
	}

	private async _getWebWorkerExtensionHostIframeSrc(): Promise<string> {
		const suffixSearchParams = new URLSearchParams();
		if (this._environmentService.debugExtensionHost && this._environmentService.debugRenderer) {
			suffixSearchParams.set('debugged', '1');
		}
		COI.addSearchParam(suffixSearchParams, true, true);

		const suffix = `?${suffixSearchParams.toString()}`;

		const iframeModulePath: AppResourcePath = `vs/workbench/services/extensions/worker/webWorkerExtensionHostIframe.html`;
		if (platform.isWeb) {
			const webEndpointUrlTemplate = this._productService.webEndpointUrlTemplate;
			const commit = this._productService.commit;
			const quality = this._productService.quality;
			if (webEndpointUrlTemplate && commit && quality) {
				// Try to keep the web worker extension host iframe origin stable by storing it in workspace storage
				const key = 'webWorkerExtensionHostIframeStableOriginUUID';
				let stableOriginUUID = this._storageService.get(key, StorageScope.WORKSPACE);
				if (typeof stableOriginUUID === 'undefined') {
					stableOriginUUID = generateUuid();
					this._storageService.store(key, stableOriginUUID, StorageScope.WORKSPACE, StorageTarget.MACHINE);
				}
				const hash = await parentOriginHash(mainWindow.origin, stableOriginUUID);
				const baseUrl = (
					webEndpointUrlTemplate
						.replace('{{uuid}}', `v--${hash}`) // using `v--` as a marker to require `parentOrigin`/`salt` verification
						.replace('{{commit}}', commit)
						.replace('{{quality}}', quality)
				);

				const res = new URL(`${baseUrl}/out/${iframeModulePath}${suffix}`);
				res.searchParams.set('parentOrigin', mainWindow.origin);
				res.searchParams.set('salt', stableOriginUUID);
				return res.toString();
			}

			console.warn(`The web worker extension host is started in a same-origin iframe!`);
		}

		const relativeExtensionHostIframeSrc = this._webWorkerService.getWorkerUrl(new WebWorkerDescriptor({
			esmModuleLocation: FileAccess.asBrowserUri(iframeModulePath),
			esmModuleLocationBundler: new URL(`../worker/webWorkerExtensionHostIframe.html`, import.meta.url),
			label: 'webWorkerExtensionHostIframe'
		}));

		return `${relativeExtensionHostIframeSrc}${suffix}`;
	}

	public async start(): Promise<IMessagePassingProtocol> {
		if (!this._protocolPromise) {
			this._protocolPromise = this._startInsideIframe();
			this._protocolPromise.then(protocol => this._protocol = protocol);
		}
		return this._protocolPromise;
	}

	private async _startInsideIframe(): Promise<IMessagePassingProtocol> {
		const webWorkerExtensionHostIframeSrc = await this._getWebWorkerExtensionHostIframeSrc();
		const emitter = this._register(new Emitter<VSBuffer>());

		const iframe = document.createElement('iframe');
		iframe.setAttribute('class', 'web-worker-ext-host-iframe');
		iframe.setAttribute('sandbox', 'allow-scripts allow-same-origin');
		iframe.setAttribute('allow', 'usb; serial; hid; cross-origin-isolated; local-network-access;');
		iframe.setAttribute('aria-hidden', 'true');
		iframe.style.display = 'none';

		const vscodeWebWorkerExtHostId = generateUuid();
		iframe.setAttribute('src', `${webWorkerExtensionHostIframeSrc}&vscodeWebWorkerExtHostId=${vscodeWebWorkerExtHostId}`);

		const barrier = new Barrier();
		let port!: MessagePort;
		let barrierError: Error | null = null;
		let barrierHasError = false;
		let startTimeout: Timeout | undefined = undefined;

		const rejectBarrier = (exitCode: number, error: Error) => {
			barrierError = error;
			barrierHasError = true;
			onUnexpectedError(barrierError);
			clearTimeout(startTimeout);
			this._onDidExit.fire([ExtensionHostExitCode.UnexpectedError, barrierError.message]);
			barrier.open();
		};

		const resolveBarrier = (messagePort: MessagePort) => {
			port = messagePort;
			clearTimeout(startTimeout);
			barrier.open();
		};

		startTimeout = setTimeout(() => {
			console.warn(`The Web Worker Extension Host did not start in 60s, that might be a problem.`);
		}, 60000);

		this._register(dom.addDisposableListener(mainWindow, 'message', (event) => {
			if (event.source !== iframe.contentWindow) {
				return;
			}
			if (event.data.vscodeWebWorkerExtHostId !== vscodeWebWorkerExtHostId) {
				return;
			}
			if (event.data.error) {
				const { name, message, stack } = event.data.error;
				const err = new Error();
				err.message = message;
				err.name = name;
				err.stack = stack;
				return rejectBarrier(ExtensionHostExitCode.UnexpectedError, err);
			}
			if (event.data.type === 'vscode.bootstrap.nls') {
				iframe.contentWindow!.postMessage({
					type: event.data.type,
					data: {
						workerUrl: this._webWorkerService.getWorkerUrl(extensionHostWorkerMainDescriptor),
						fileRoot: globalThis._VSCODE_FILE_ROOT,
						nls: {
							messages: getNLSMessages(),
							language: getNLSLanguage()
						}
					}
				}, '*');
				return;
			}
			const { data } = event.data;
			if (barrier.isOpen() || !(data instanceof MessagePort)) {
				console.warn('UNEXPECTED message', event);
				const err = new Error('UNEXPECTED message');
				return rejectBarrier(ExtensionHostExitCode.UnexpectedError, err);
			}
			resolveBarrier(data);
		}));

		this._layoutService.mainContainer.appendChild(iframe);
		this._register(toDisposable(() => iframe.remove()));

		// await MessagePort and use it to directly communicate
		// with the worker extension host
		await barrier.wait();

		if (barrierHasError) {
			throw barrierError;
		}

		// Send over message ports for extension API
		const messagePorts = this._environmentService.options?.messagePorts ?? new Map();
		iframe.contentWindow!.postMessage({ type: 'vscode.init', data: messagePorts }, '*', [...messagePorts.values()]);

		port.onmessage = async (event) => {
			const { data } = event;
			if (!(data instanceof ArrayBuffer)) {

				if (data?.type.startsWith(nodepodClientPrefix)) {

					const { type, id, clientId } = event.data;

					let clientState = clients.get(clientId);
					if (!clientState) {
						clientState = new ClientState(clientId);
						clients.set(clientId, clientState);
						await clientState.startMainProcess((window.parent as any).nodepod);
					}
					if (type === nodepodClientPrefix + "process" ||
						type === nodepodClientPrefix + "util" ||
						type === nodepodClientPrefix + "tty" ||
						type === nodepodClientPrefix + "path" ||
						type === nodepodClientPrefix + "readline.createInterface" ||
						type === nodepodClientPrefix + "child_process.spawn" ||
						type === nodepodClientPrefix + "child_process.execFile" ||
						type === nodepodClientPrefix + "child_process.execFileSync" ||
						type === nodepodClientPrefix + "child_process.execSync"
					) {
						const result = await clientState.send({ type: type.replace(nodepodClientPrefix, '') });
						port.postMessage({
							type,
							id,
							result,
						});
					}

					if (type === nodepodClientPrefix + "fs.existsSync" ||
						type === nodepodClientPrefix + "fs.readFileSync" ||
						type === nodepodClientPrefix + "fs.createReadStream" ||
						type === nodepodClientPrefix + "fs.mkdirSync" ||
						type === nodepodClientPrefix + "fs.readdirSync" ||
						type === nodepodClientPrefix + "fs.statSync" ||
						type === nodepodClientPrefix + "fs.unlinkSync" ||
						type === nodepodClientPrefix + "fs.rmdirSync" ||
						type === nodepodClientPrefix + "fs.rmSync" ||
						type === nodepodClientPrefix + "fsp.access" ||
						type === nodepodClientPrefix + "fsp.readdir" ||
						type === nodepodClientPrefix + "fsp.stat" ||
						type === nodepodClientPrefix + "fsp.mkdir" ||
						type === nodepodClientPrefix + "fsp.readFile" ||
						type === nodepodClientPrefix + "fsp.rm"
					) {
						const result = clientState.fs[type.replace(nodepodClientPrefix, '').replace('fsp.', 'fs.').replace('.fs.', '')](event.data.params.path);
						port.postMessage({
							type,
							id,
							result,
						});
					}

					if (type === nodepodClientPrefix + "fs.writeFileSync") {
						const result = clientState.fs.writeFileSync(event.data.params.path, event.data.params.data);
						port.postMessage({
							type: nodepodClientPrefix + "fs.writeFileSync",
							id: id,
							result: result,
						});
					}
					if (type === nodepodClientPrefix + "fs.renameSync") {
						const result = clientState.fs.renameSync(event.data.params.oldPath, event.data.params.newPath);
						port.postMessage({
							type: nodepodClientPrefix + "fs.renameSync",
							id: id,
							result: result,
						});
					}

					if (type === nodepodClientPrefix + "fsp.writeFile") {
						const result = clientState.fs.writeFile(event.data.params.path, event.data.params.data);
						port.postMessage({
							type: nodepodClientPrefix + "fsp.writeFile",
							id: id,
							result: result,
						});
					}
					if (type === nodepodClientPrefix + "fs.chmodSync") {
						const result = clientState.fs.chmodSync(event.data.params.path, event.data.params.mode);
						port.postMessage({
							type: nodepodClientPrefix + "fs.chmodSync",
							id: id,
							result: result,
						});
					}

					if (type === nodepodClientPrefix + "fs.copyFileSync") {
						const result = clientState.fs.copyFileSync(event.data.params.src, event.data.params.dest);
						port.postMessage({
							type: nodepodClientPrefix + "fs.copyFileSync",
							id: id,
							result: result,
						});
					}

					return;
				}
				console.warn('UNKNOWN data received', data);
				this._onDidExit.fire([77, 'UNKNOWN data received']);
				return;
			}
			emitter.fire(VSBuffer.wrap(new Uint8Array(data, 0, data.byteLength)));
		};

		const protocol: IMessagePassingProtocol = {
			onMessage: emitter.event,
			send: vsbuf => {
				const data = vsbuf.buffer.buffer.slice(vsbuf.buffer.byteOffset, vsbuf.buffer.byteOffset + vsbuf.buffer.byteLength);
				port.postMessage(data, [data]);
			}
		};

		return this._performHandshake(protocol);
	}

	private async _performHandshake(protocol: IMessagePassingProtocol): Promise<IMessagePassingProtocol> {
		// extension host handshake happens below
		// (1) <== wait for: Ready
		// (2) ==> send: init data
		// (3) <== wait for: Initialized

		await Event.toPromise(Event.filter(protocol.onMessage, msg => isMessageOfType(msg, MessageType.Ready)));
		if (this._isTerminating) {
			throw canceled();
		}
		protocol.send(VSBuffer.fromString(JSON.stringify(await this._createExtHostInitData())));
		if (this._isTerminating) {
			throw canceled();
		}
		await Event.toPromise(Event.filter(protocol.onMessage, msg => isMessageOfType(msg, MessageType.Initialized)));
		if (this._isTerminating) {
			throw canceled();
		}

		return protocol;
	}

	public override dispose(): void {
		if (this._isTerminating) {
			return;
		}
		this._isTerminating = true;
		this._protocol?.send(createMessageOfType(MessageType.Terminate));
		super.dispose();
	}

	getInspectPort(): undefined {
		return undefined;
	}

	enableInspectPort(): Promise<boolean> {
		return Promise.resolve(false);
	}

	private async _createExtHostInitData(): Promise<IExtensionHostInitData> {
		const initData = await this._initDataProvider.getInitData();
		this.extensions = initData.extensions;
		const workspace = this._contextService.getWorkspace();
		const nlsBaseUrl = this._productService.extensionsGallery?.nlsBaseUrl;
		let nlsUrlWithDetails: URI | undefined = undefined;
		// Only use the nlsBaseUrl if we are using a language other than the default, English.
		if (nlsBaseUrl && this._productService.commit && !platform.Language.isDefaultVariant()) {
			nlsUrlWithDetails = URI.joinPath(URI.parse(nlsBaseUrl), this._productService.commit, this._productService.version, platform.Language.value());
		}
		return {
			commit: this._productService.commit,
			version: this._productService.version,
			quality: this._productService.quality,
			date: this._productService.date,
			parentPid: 0,
			environment: {
				isExtensionDevelopmentDebug: this._environmentService.debugRenderer,
				appName: this._productService.nameLong,
				appHost: this._productService.embedderIdentifier ?? (platform.isWeb ? 'web' : 'desktop'),
				appUriScheme: this._productService.urlProtocol,
				appLanguage: platform.language,
				isExtensionTelemetryLoggingOnly: isLoggingOnly(this._productService, this._environmentService),
				isPortable: false,
				extensionDevelopmentLocationURI: this._environmentService.extensionDevelopmentLocationURI,
				extensionTestsLocationURI: this._environmentService.extensionTestsLocationURI,
				globalStorageHome: this._userDataProfilesService.defaultProfile.globalStorageHome,
				workspaceStorageHome: this._environmentService.workspaceStorageHome,
				extensionLogLevel: this._defaultLogLevelsService.defaultLogLevels.extensions,
				isSessionsWindow: this._environmentService.isSessionsWindow
			},
			workspace: this._contextService.getWorkbenchState() === WorkbenchState.EMPTY ? undefined : {
				configuration: workspace.configuration || undefined,
				id: workspace.id,
				name: this._labelService.getWorkspaceLabel(workspace),
				transient: workspace.transient
			},
			consoleForward: {
				includeStack: false,
				logNative: this._environmentService.debugRenderer
			},
			extensions: this.extensions.toSnapshot(),
			nlsBaseUrl: nlsUrlWithDetails,
			telemetryInfo: {
				sessionId: this._telemetryService.sessionId,
				machineId: this._telemetryService.machineId,
				sqmId: this._telemetryService.sqmId,
				devDeviceId: this._telemetryService.devDeviceId ?? this._telemetryService.machineId,
				firstSessionDate: this._telemetryService.firstSessionDate,
				msftInternal: this._telemetryService.msftInternal
			},
			remoteExtensionTips: this._productService.remoteExtensionTips,
			virtualWorkspaceExtensionTips: this._productService.virtualWorkspaceExtensionTips,
			logLevel: this._logService.getLevel(),
			loggers: [...this._loggerService.getRegisteredLoggers()],
			logsLocation: this._extensionHostLogsLocation,
			autoStart: (this.startup === ExtensionHostStartup.EagerAutoStart || this.startup === ExtensionHostStartup.LazyAutoStart),
			remote: {
				authority: this._environmentService.remoteAuthority,
				connectionData: null,
				isRemote: false
			},
			uiKind: platform.isWeb ? UIKind.Web : UIKind.Desktop
		};
	}
}

const extensionHostWorkerMainDescriptor = new WebWorkerDescriptor({
	label: 'extensionHostWorkerMain',
	esmModuleLocation: () => FileAccess.asBrowserUri('vs/workbench/api/worker/extensionHostWorkerMain.js'),
	esmModuleLocationBundler: () => new URL('../../../api/worker/extensionHostWorkerMain.ts?esm', import.meta.url),
});
