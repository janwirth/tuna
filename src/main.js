// Modules to control application life and create native browser window
const {app, BrowserWindow} = require('electron')
const path = require('path')
require('electron-reload')(__dirname, {ignored: /node_modules|[\/\\]\.|library.json/, argv: []});
const { session } = require('electron')
const { register } = require('./custom-elements')
const FileSystem = require('./FileSystem')
FileSystem.ensureTunaDir()

// increase memory limit to prevent elm debug from choking on large lists
// https://discourse.elm-lang.org/t/rangeerror-maximum-call-stack-size-exceeded-when-decoding-a-long-list/4605
app.commandLine.appendSwitch('js-flags', '--stack-size 20000 --max-old-space-size=8192');


// pierce 3rd-party integrations through security layers
// @@TODO: keep security in mind
const {allowAppAsFrameAncestor, setup} = require('./security.js')
setup(app);



(async () =>  {
  await app.whenReady()

  app.removeAsDefaultProtocolClient('app')
  app.setAsDefaultProtocolClient('app')

  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    frame: false,
    // we show the window inactive to not interfere with what the user is currently doing
    // In this case, I am the user - the developer and my editor losing focus annoys me :sad-face:

    webPreferences: {
      preload: path.join(__dirname, 'browser-main.js'),
      nodeIntegration: true,
      webSecurity: false,
      nativeWindowOpen: true // allow elm to spawn a debugger
    }
  })

  allowAppAsFrameAncestor(mainWindow.webContents.session)

  // The above is equivalent to this:
  console.log(__dirname)
  await mainWindow.loadURL(`file://${__dirname}/../index.html`);
  // and load the index.html of the app.
  // mainWindow.loadFile('index.html')

  // Open the DevTools.
  mainWindow.webContents.openDevTools()
})();

// Quit when all windows are closed.
app.on('window-all-closed', function () {
  // On macOS it is common for applications and their menu bar
  // to stay active until the user quits explicitly with Cmd + Q
  if (process.platform !== 'darwin') app.quit()
})

app.on('activate', function () {
  // On macOS it's common to re-create a window in the app when the
  // dock icon is clicked and there are no other windows open.
  if (BrowserWindow.getAllWindows().length === 0) createWindow()
})
