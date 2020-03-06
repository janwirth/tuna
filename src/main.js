// Modules to control application life and create native browser window
const {app, BrowserWindow} = require('electron')
const path = require('path')
require('electron-reload')(__dirname, {ignored: /node_modules|[\/\\]\.|library.json/, argv: []});
const { session } = require('electron')
const { register } = require('./custom-elements')

const os = require('os');

const platforms = {
  WINDOWS: 'WINDOWS',
  MAC: 'MAC',
  LINUX: 'LINUX',
  SUN: 'SUN',
  OPENBSD: 'OPENBSD',
  ANDROID: 'ANDROID',
  AIX: 'AIX',
};

const platformsNames = {
  win32: platforms.WINDOWS,
  darwin: platforms.MAC,
  linux: platforms.LINUX,
  sunos: platforms.SUN,
  openbsd: platforms.OPENBSD,
  android: platforms.ANDROID,
  aix: platforms.AIX,
};

const currentPlatform = platformsNames[os.platform()];

// file server
const serve = require('electron-serve');
const loadURL = serve({directory: '.'});

// start backend server
require('./backend')

// pierce 3rd-party integrations through security layers
// @@TODO: keep security in mind
const {allowAppAsFrameAncestor, setup} = require('./security.js')
setup(app)



async function createWindow () {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    frame: false,
    // we show the window inactive to not interfere with what the user is currently doing
    // In this case, I am the user - the developer and my editor losing focus annoys me :sad-face:

    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: true,
      webSecurity: false
    }
  })

  allowAppAsFrameAncestor(mainWindow.webContents.session)

  await loadURL(mainWindow);

  // The above is equivalent to this:
  await mainWindow.loadURL('app://tuna');
  // and load the index.html of the app.
  // mainWindow.loadFile('index.html')

  // Open the DevTools.
  mainWindow.webContents.openDevTools()
}


// This method will be called when Electron has finished
// initialization and is ready to create browser windows.
// Some APIs can only be used after this event occurs.
app.on('ready', createWindow)

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
