cd /home/a/webcode7/vscode/build/vite

killall google-chrome
echo "Killed google-chrome"
rm -rf /home/a/webcode7/vscode/src/vs/workbench/services/keybinding/browser/keyboardLayouts/*.js
rm -rf /home/a/webcode7/vscode/src/vs/base/common/*.js
rm -rf /home/a/webcode7/vscode/src/vs/platform/keybinding/common/*.js
rm -rf /home/a/webcode7/vscode/src/vs/platform/contextkey/common/*.js
echo "Removed files"
echo "Building vite"
cd /home/a/webcode7/vscode/build/vite
npm run build
echo "Vite built"
echo "Compiling vscode"

cd /home/a/webcode7/vscode
npm run compile
echo "Vscode compiled"

#echo "Compiling keyboard layout"
#npx tsgo src/vs/workbench/services/keybinding/browser/keyboardLayouts/layout.contribution.linux.ts
#echo "Keyboard layout compiled"

echo "Copying files"
cp -r /home/a/webcode7/vscode/resources/server/favicon.ico /home/a/webcode7/vscode/build/vite/dist/favicon.ico
cp -r /home/a/webcode7/vscode/build/vite/server.js /home/a/webcode7/vscode/build/vite/dist/server.js
cp -r /home/a/webcode7/vscode/build/vite/nodepodSW.js /home/a/webcode7/vscode/build/vite/dist/nodepodSW.js
cp -r /home/a/webcode7/vscode/build/vite/build.sh /home/a/webcode7/vscode/build/vite/dist/build.sh
cp -r /home/a/webcode7/vscode/build/vite/marketplace.json /home/a/webcode7/vscode/build/vite/dist/marketplace.json
echo "Files copied"

echo "Creating directories"
mkdir -p /home/a/webcode7/vscode/build/vite/dist/static/
mkdir -p /home/a/webcode7/vscode/build/vite/dist/static/sources/
echo "Directories created"

echo "Copying files to directories"
cp -r /home/a/webcode7/vscode/out/ /home/a/webcode7/vscode/build/vite/dist/static/sources/
#cp -r /home/a/webcode7/vscode/src/vs/workbench/services/keybinding/browser/keyboardLayouts/*.js /home/a/webcode7/vscode/build/vite/dist/static/sources/out/vs/workbench/services/keybinding/browser/keyboardLayouts/
cp -r /home/a/webcode7/vscode/build/vite/dist/static/sources/out /home/a/webcode7/vscode/build/vite/dist/
cp -r /home/a/webcode7/vscode/node_modules/ /home/a/webcode7/vscode/build/vite/dist/node_modules/
cp -r /home/a/webcode7/vscode/extensions/ /home/a/webcode7/vscode/build/vite/dist/extensions/

npx prettier --write /home/a/kimi-agent-sdk/node/vscode_extension/dist/extension.js --ignore-path /dev/null


#!/bin/bash

TARGET_FILE="/home/a/kimi-agent-sdk/node/vscode_extension/dist/extension.js"  # Update path as needed

PREPEND_CODE='debugger;
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
this.worker.addEventListener("message", (event) => {
const { type, id, result } = event.data;
if (type === this.nodepodClientPrefix + "process") {
const resolveFunc = this.promises.get(id);
if (resolveFunc) {
          resolveFunc(result);
this.promises.delete(id);
        }
      }
    });
  }
  createPostMessagePromise(type) {
const currentId = this.promiseId++;
let resolveFunc = null;
const postMessagePromise = new Promise((resolve, reject) => {
      resolveFunc = resolve;
    });
this.promises.set(currentId, resolveFunc);
this.worker.postMessage({
      type: type,
      id: currentId,
      clientId: this.clientId,
    });
return postMessagePromise;
  }
async require(module) {
if (module === "process") {
return this.createPostMessagePromise(this.nodepodClientPrefix + "process");
    }
  }
}
(async () => {
const client = new NodepodClient(self, "kimi");
const process = await client.require("process");
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


cp -r /home/a/kimi-agent-sdk/node/vscode_extension /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/


echo "Files copied to directories"

echo "Starting server"
cd /home/a/webcode7/vscode/build/vite/dist
killall node
node server.js & google-chrome --disable-web-security --disable-features=IsolateOrigins,site-per-process --disable-site-isolation-trials --user-data-dir="/home/a/UserDataDir1" --enable-features=SharedArrayBuffer https://webcode.host/build/vite/workbench-vite.html

