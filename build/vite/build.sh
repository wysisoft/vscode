# cd /home/a/webcode7/vscode/build/vite

# killall google-chrome
# echo "Killed google-chrome"
# rm -rf /home/a/webcode7/vscode/src/vs/workbench/services/keybinding/browser/keyboardLayouts/*.js
# rm -rf /home/a/webcode7/vscode/src/vs/base/common/*.js
# rm -rf /home/a/webcode7/vscode/src/vs/platform/keybinding/common/*.js
# rm -rf /home/a/webcode7/vscode/src/vs/platform/contextkey/common/*.js
# echo "Removed files"
# echo "Building vite"
# cd /home/a/webcode7/vscode/build/vite
# npm run build
# echo "Vite built"
# echo "Compiling vscode"

# cd /home/a/webcode7/vscode
# npm run compile
# echo "Vscode compiled"

# #echo "Compiling keyboard layout"
# #npx tsgo src/vs/workbench/services/keybinding/browser/keyboardLayouts/layout.contribution.linux.ts
# #echo "Keyboard layout compiled"

# echo "Copying files"
# cp -r /home/a/webcode7/vscode/resources/server/favicon.ico /home/a/webcode7/vscode/build/vite/dist/favicon.ico
# cp -r /home/a/webcode7/vscode/build/vite/server.js /home/a/webcode7/vscode/build/vite/dist/server.js
# cp -r /home/a/webcode7/vscode/build/vite/nodepodSW.js /home/a/webcode7/vscode/build/vite/dist/nodepodSW.js
# cp -r /home/a/webcode7/vscode/build/vite/build.sh /home/a/webcode7/vscode/build/vite/dist/build.sh
# cp -r /home/a/webcode7/vscode/build/vite/marketplace.json /home/a/webcode7/vscode/build/vite/dist/marketplace.json
# echo "Files copied"

# echo "Creating directories"
# mkdir -p /home/a/webcode7/vscode/build/vite/dist/static/
# mkdir -p /home/a/webcode7/vscode/build/vite/dist/static/sources/
# echo "Directories created"

# echo "Copying files to directories"
# cp -r /home/a/webcode7/vscode/out/ /home/a/webcode7/vscode/build/vite/dist/static/sources/
# #cp -r /home/a/webcode7/vscode/src/vs/workbench/services/keybinding/browser/keyboardLayouts/*.js /home/a/webcode7/vscode/build/vite/dist/static/sources/out/vs/workbench/services/keybinding/browser/keyboardLayouts/
# cp -r /home/a/webcode7/vscode/build/vite/dist/static/sources/out /home/a/webcode7/vscode/build/vite/dist/
# cp -r /home/a/webcode7/vscode/node_modules/ /home/a/webcode7/vscode/build/vite/dist/node_modules/
# cp -r /home/a/webcode7/vscode/extensions/ /home/a/webcode7/vscode/build/vite/dist/extensions/

rm -rf /home/a/kimi-agent-sdk/node/vscode_extension/dist

cd /home/a/kimi-agent-sdk/node/vscode_extension
npm run build
npx prettier --write /home/a/kimi-agent-sdk/node/vscode_extension/dist/extension.js --ignore-path /dev/null


#!/bin/bash

TARGET_FILE="/home/a/kimi-agent-sdk/node/vscode_extension/dist/extension.js"  # Update path as needed

PREPEND_CODE='
(async () => {

  debugger;
  class NodepodClient {
    promiseId = 0;
    promises = new Map();
    nodepodClientPrefix = "nodepodClient:";
    worker;
    clientId;
    // Process object with env and deprecation flags
    process;
    constructor(worker, clientId) {
      this.clientId = clientId;
      this.worker = worker;
      // Initialize process with defaults
      this.process = {
        env: {},
        noDeprecation: false,
        throwDeprecation: false,
        traceDeprecation: false,
      };
      globalThis.__extensionUserPort.onmessage = (event) => {
        const { type, id, result } = event.data;
        if (type === this.nodepodClientPrefix + "process") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "util") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            result.deprecate = nodepod_util_deprecate;
            result.promisify = nodepod_util_promisify;
            result.format = nodepod_util_format;
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "tty") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            result.isatty = nodepod_tty_isatty;
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "path") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "child_process.spawn") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "child_process.execFile") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "child_process.execFileSync") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if (type === this.nodepodClientPrefix + "child_process.execSync") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
        if(type === this.nodepodClientPrefix + "readline.createInterface") {
          const resolveFunc = this.promises.get(id);
          if (resolveFunc) {
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
      };
    }
    createPostMessagePromise(type, params) {
      const currentId = this.promiseId++;
      let resolveFunc = null;
      const postMessagePromise = new Promise((resolve, reject) => {
        resolveFunc = resolve;
      });
      this.promises.set(currentId, resolveFunc);

      globalThis.__extensionUserPort.postMessage({
        type: type,
        id: currentId,
        clientId: this.clientId,
        params: params,
      });
      return postMessagePromise;
    }
    async polyfill(module) {
      if (module === "process") {
        return this.createPostMessagePromise(this.nodepodClientPrefix + "process");
      }
      if (module === "util") {
        return{
        promisify: nodepod_util_promisify,
        deprecate: nodepod_util_deprecate,
        format: nodepod_util_format,
        }
      }
      if (module === "tty") {
        return {
          isatty: nodepod_tty_isatty,
        }
      }
      if (module === "path") {
        return {
          sep: nodepod_path_sep,
          dirname: nodepod_path_dirname,
          basename: nodepod_path_basename,
          extname: nodepod_path_extname,
          join: nodepod_path_join,
          resolve: nodepod_path_resolve,
          normalize: nodepod_path_normalize,
          isAbsolute: nodepod_path_isAbsolute,
          relative: nodepod_path_relative,
        }
      }
      if (module === "crypto") {
        return {
          createHash: nodepod_crypto_createHash,
          randomUUID: nodepod_crypto_randomUUID,
        }
      }
      if (module === "child_process") {
        return {
          spawn: (command, args, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "child_process.spawn", { command, args, options });
          },
          execFile: (file, args, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "child_process.execFile", { file, args, options });
          },
          execFileSync: (file, args, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "child_process.execFileSync", { file, args, options });
          },
          execSync: (command, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "child_process.execSync", { command, options });
          },
        }
      }
       if (module === "readline") {
        return {
          createInterface: (options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "readline.createInterface", { options });
          },
        }
      }

      if (module === "fs") {
        return {
          existsSync: (target) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.existsSync", { target });
          },
          readFileSync: (path, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.readFileSync", { path, options });
          },
          writeFileSync: (path, data, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.writeFileSync", { path, data, options });
          },
          createReadStream: (path, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.createReadStream", { path, options });
          },
          mkdirSync: (path, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.mkdirSync", { path, options });
          },
          readdirSync: (path, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.readdirSync", { path, options });
          },
          statSync: (path, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.statSync", { path, options });
          },
          chmodSync: (path, mode) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.chmodSync", { path, mode });
          },
          unlinkSync: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.unlinkSync", { path });
          },
          copyFileSync: (src, dest) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.copyFileSync", { src, dest });
          },
          renameSync: (oldPath, newPath) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.renameSync", { oldPath, newPath });
          },
          rmdirSync: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.rmdirSync", { path });
          },
          rmSync: (path, options) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs.rmSync", { path, options });
          },
        }
      }

      if (module === "fs/promises") {
        return {
          access: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.access", { path });
          },
          readdir: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.readdir", { path });
          },
          stat: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.stat", { path });
          },
          mkdir: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.mkdir", { path });
          },
          writeFile: (path, data) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.writeFile", { path, data });
          },
          readFile: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.readFile", { path });
          },
          rm: (path) => {
            return this.createPostMessagePromise(this.nodepodClientPrefix + "fs/promises.rm", { path });
          }
        }
      }

      if(module === "os") {
        return {
          homedir: ()=>"/home",
          tmpdir: ()=>"/tmp",
        }
      }
    }
  }

  const client = new NodepodClient(self, "kimi");
  self.nodepodClient = client;
  const process = await client.polyfill("process");
  const nodepod_util = await client.polyfill("util");
  const nodepod_tty = await client.polyfill("tty");
  const nodepod_path = await client.polyfill("path");
  const nodepod_child_process = await client.polyfill("child_process");
  const nodepod_crypto = await client.polyfill("crypto");
  const nodepod_readline = await client.polyfill("readline");
  const nodepod_fs = await client.polyfill("fs");
  const nodepod_fs_promises = await client.polyfill("fs/promises");
  const nodepod_os = await client.polyfill("os");

'

APPEND_CODE='})()
'

# Check the file exists
if [ ! -f "$TARGET_FILE" ]; then
  echo "Error: File '$TARGET_FILE' not found."
  exit 1
fi

# Prepend and append
{ echo "$PREPEND_CODE"; cat "$TARGET_FILE"; echo "$APPEND_CODE"; } > "$TARGET_FILE.tmp" && mv "$TARGET_FILE.tmp" "$TARGET_FILE"

echo "Done. Code prepended and appended to '$TARGET_FILE'."

sed -i 's/require("tty")/nodepod_tty/g' $TARGET_FILE
sed -i 's/require("util")/nodepod_util/g' $TARGET_FILE
sed -i 's/require("path")/nodepod_path/g' $TARGET_FILE
sed -i 's/require("node:path")/nodepod_path/g' $TARGET_FILE
sed -i 's/require("child_process")/nodepod_child_process/g' $TARGET_FILE
sed -i 's/require("node:child_process")/nodepod_child_process/g' $TARGET_FILE
sed -i 's/require("crypto")/nodepod_crypto/g' $TARGET_FILE
sed -i 's/require("node:crypto")/nodepod_crypto/g' $TARGET_FILE
sed -i 's/require("node:readline")/nodepod_readline/g' $TARGET_FILE
sed -i 's/require("fs")/nodepod_fs/g' $TARGET_FILE
sed -i 's/require("fs\/promises")/nodepod_fs_promises/g' $TARGET_FILE
sed -i 's/require("node:fs")/nodepod_fs/g' $TARGET_FILE
sed -i 's/require("node:fs\/promises")/nodepod_fs_promises/g' $TARGET_FILE
sed -i 's/require("os")/nodepod_os/g' $TARGET_FILE
sed -i 's/require("node:os")/nodepod_os/g' $TARGET_FILE

rm -rf /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/
cp -r /home/a/kimi-agent-sdk/node/vscode_extension /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/

cp -r /home/a/webcode7/vscode/node_modules/@scelar/nodepod/src ~/webcode7/vscode/build/vite/dist/extensions/kimi/dist

cd /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist
npm i --save-dev @types/node

cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "outDir": "/home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist",
    "module": "CommonJS",
    "target": "ES2020",
    "types": ["node"],
    "rootDir": "/home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist",
    "noImplicitAny": false
  },
  "exclude": ["NOTHING_TO_EXCLUDE"],
  "include": ["/home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist/polyfills.ts"]
}

EOF


cat > polyfills.ts << 'EOF'
"use strict";
import { deprecate,promisify,format } from "./src/polyfills/util";
import { isatty } from "./src/polyfills/tty";
import { createHash,randomUUID } from "./src/polyfills/crypto";
import {sep,dirname,basename,extname,join,resolve,normalize,isAbsolute,relative} from "./src/polyfills/path";

const nodepod_util_deprecate = deprecate;
void nodepod_util_deprecate;
const nodepod_util_promisify = promisify;
void nodepod_util_promisify;
const nodepod_util_format = format;
void nodepod_util_format;

const nodepod_tty_isatty = isatty;
void nodepod_tty_isatty;

const nodepod_crypto_createHash = createHash;
void nodepod_crypto_createHash;
const nodepod_crypto_randomUUID = randomUUID;
void nodepod_crypto_randomUUID;

const nodepod_path_sep = sep;
void nodepod_path_sep;
const nodepod_path_dirname = dirname;
void nodepod_path_dirname;
const nodepod_path_basename = basename;
void nodepod_path_basename;
const nodepod_path_extname = extname;
void nodepod_path_extname;
const nodepod_path_join = join;
void nodepod_path_join;
const nodepod_path_resolve = resolve;
void nodepod_path_resolve;
const nodepod_path_normalize = normalize;
void nodepod_path_normalize;
const nodepod_path_isAbsolute = isAbsolute;
void nodepod_path_isAbsolute;
const nodepod_path_relative = relative;
void nodepod_path_relative;

EOF

npx tsc

npx esbuild ./polyfills.js --bundle --platform=browser --format=cjs --outfile=polyfills.js --log-level=debug --allow-overwrite

#combine extension.js and polyfills.ts into extension.js
cat polyfills.js extension.js > extension.tmp.js && mv extension.tmp.js extension.js

echo "Files copied to directories"

echo "Starting server"
cd /home/a/webcode7/vscode/build/vite/dist
killall node
node server.js & google-chrome --disable-web-security --disable-features=IsolateOrigins,site-per-process --disable-site-isolation-trials --user-data-dir="/home/a/UserDataDir1" --enable-features=SharedArrayBuffer https://webcode.host/build/vite/workbench-vite.html
