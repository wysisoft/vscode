rm -rf /home/a/webcode7/vscode/src/vs/workbench/services/keybinding/browser/keyboardLayouts/*.js
rm -rf /home/a/webcode7/vscode/src/vs/base/common/*.js
rm -rf /home/a/webcode7/vscode/src/vs/platform/keybinding/common/*.js
rm -rf /home/a/webcode7/vscode/src/vs/platform/contextkey/common/*.js


cd /home/a/webcode7/vscode
npm run compile

cd /home/a/webcode7/vscode/build/vite
npm run build

cp -r /home/a/webcode7/vscode/resources/server/favicon.ico /home/a/webcode7/vscode/build/vite/dist/favicon.ico
cp -r /home/a/webcode7/vscode/build/vite/server.js /home/a/webcode7/vscode/build/vite/dist/server.js
cp -r /home/a/webcode7/vscode/build/vite/nodepodSW.js /home/a/webcode7/vscode/build/vite/dist/nodepodSW.js
cp -r /home/a/webcode7/vscode/build/vite/build.sh /home/a/webcode7/vscode/build/vite/dist/build.sh
cp -r /home/a/webcode7/vscode/build/vite/marketplace.json /home/a/webcode7/vscode/build/vite/dist/marketplace.json
mkdir -p /home/a/webcode7/vscode/build/vite/dist/static/
mkdir -p /home/a/webcode7/vscode/build/vite/dist/static/sources/
cp -r /home/a/webcode7/vscode/out/ /home/a/webcode7/vscode/build/vite/dist/static/sources/

npx tsgo src/vs/workbench/services/keybinding/browser/keyboardLayouts/layout.contribution.linux.ts
cp -r /home/a/webcode7/vscode/src/vs/workbench/services/keybinding/browser/keyboardLayouts/*.js /home/a/webcode7/vscode/build/vite/dist/static/sources/out/vs/workbench/services/keybinding/browser/keyboardLayouts/

cp -r /home/a/webcode7/vscode/build/vite/dist/static/sources/out /home/a/webcode7/vscode/build/vite/dist/

cd /home/a/webcode7/vscode/build/vite/dist
killall node
node server.js
