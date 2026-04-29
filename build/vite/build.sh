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
            resolveFunc(result);
            this.promises.delete(id);
          }
        }
      };
    }
    createPostMessagePromise(type) {
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
      });
      return postMessagePromise;
    }
    async polyfill(module) {
      if (module === "process") {
        return this.createPostMessagePromise(this.nodepodClientPrefix + "process");
      }
      if (module === "util") {
        return this.createPostMessagePromise(this.nodepodClientPrefix + "util");
      }
      if (module === "tty") {
        return this.createPostMessagePromise(this.nodepodClientPrefix + "tty");
      }
    }
  }

  const client = new NodepodClient(self, "kimi");
  self.nodepodClient = client;
  const process = await client.polyfill("process");
  const nodepod_util = await client.polyfill("util");
  const nodepod_tty = await client.polyfill("tty");
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

rm -rf /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/
cp -r /home/a/kimi-agent-sdk/node/vscode_extension /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/

cp  /home/a/webcode7/vscode/node_modules/@scelar/nodepod/src/polyfills/util.ts ~/webcode7/vscode/build/vite/dist/extensions/kimi/dist/nodepod_util.ts

cd /home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist
npm i --save-dev @types/node

cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "outDir": "/home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist",
    "module": "CommonJS",
    "target": "ES2019",
    "types": ["node"]
  },
  "exclude": ["NOTHING_TO_EXCLUDE"],
  "include": ["/home/a/webcode7/vscode/build/vite/dist/extensions/kimi/dist/polyfills.ts"]
}
EOF


cat > polyfills.ts << 'EOF'
"use strict";
import { deprecate } from "./nodepod_util";
const nodepod_util_deprecate = deprecate;
void nodepod_util_deprecate;
EOF

npx tsgo

npx esbuild ./polyfills.js --bundle --platform=browser --format=cjs --outfile=polyfills.js --log-level=debug --allow-overwrite

#combine extension.js and polyfills.ts into extension.js
cat polyfills.js extension.js > extension.tmp.js && mv extension.tmp.js extension.js

echo "Files copied to directories"

echo "Starting server"
cd /home/a/webcode7/vscode/build/vite/dist
killall node
node server.js & google-chrome --disable-web-security --disable-features=IsolateOrigins,site-per-process --disable-site-isolation-trials --user-data-dir="/home/a/UserDataDir1" --enable-features=SharedArrayBuffer https://webcode.host/build/vite/workbench-vite.html
