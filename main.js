// Modules to control application life and create native browser window
const {app, BrowserWindow} = require('electron')
const path = require('path')
require('electron-reload')(__dirname, {ignored: /node_modules|[\/\\]\.|library.json/, argv: []});
const fs = require('fs')
const LIBRARY_FILE = './library.json'

const http = require('http');

const requestListener = function (req, res) {
    const request = req
  console.log(req.url)
  switch (req.url) {
      case '/persist':
        persist(req, res)
      case '/restore':
        restore(req, res)
  }
}
const restore = (req, res) => {
    console.log('restoring')
    try {
        const data = fs.readFileSync(LIBRARY_FILE).toString()
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.write(data)
        console.log('restored')
    } catch (e) {
    }
    res.end()
}

const persist = (req, res) => {
    console.log('persisting')
    let body = [];
    req.on('data', (chunk) => {
      body.push(chunk);
    }).on('end', () => {
      body = Buffer.concat(body).toString();
      // at this point, `body` has the entire request body stored in it as a string
      fs.writeFileSync(LIBRARY_FILE, body)
      res.writeHead(200, {'Content-Type': 'application/json'});
      res.end()
      console.log('persisted')
    });
}

const server = http.createServer(requestListener);
server.listen(8080);

function createWindow () {
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  })

  // and load the index.html of the app.
  mainWindow.loadFile('index.html')

  // Open the DevTools.
  // mainWindow.webContents.openDevTools()
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

// In this file you can include the rest of your app's specific main process
// code. You can also put them in separate files and require them here.
