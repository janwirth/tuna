// Modules to control application life and create native browser window
const {app, BrowserWindow} = require('electron')
const path = require('path')
require('electron-reload')(__dirname, {ignored: /node_modules|[\/\\]\.|library.json/, argv: []});
const fs = require('fs')
const LIBRARY_FILE = './library.json'
const mime = require('mime-types')
const { session } = require('electron')
const http = require('http');
const serve = require('electron-serve');

app.commandLine.appendSwitch('disable-site-isolation-trials')

const loadURL = serve({directory: '.'});

const requestListener = function (req, res) {
    const request = req
  console.log('[REQUEST]', req.url)
  switch (req.url) {
      case '/persist':
        persist(req, res)
        console.log('[REQUEST] done')
        break;
      case '/restore':
        restore(req, res)
        console.log('[REQUEST] done')
        break;
      case '/import':
        import_(req, res)
        console.log('[REQUEST] done')
        break;
  }
}
const restore = (req, res) => {
    try {
        const data = fs.readFileSync(LIBRARY_FILE).toString()
        res.writeHead(200, {'Content-Type': 'application/json'});
        res.write(data)
    } catch (e) {
    }
    res.end()
}

// read files inside directories and return file ref
const import_ = (req, res) => {
    let body = [];
    req.on('data', (chunk) => {
      body.push(chunk);
    }).on('end', () => {
      body = Buffer.concat(body).toString();
      directories = JSON.parse(body)
      const files = Array.prototype.concat(...directories.map(scan))
      // at this point, `body` has the entire request body stored in it as a string
      res.writeHead(200, {'Content-Type': 'application/json'});
      res.write(JSON.stringify(files))
      res.end()
    });
}
const scan = directory => {
    return Array.prototype.concat(...fs.readdirSync(directory).map(fileName => {
        const fullPath = path.join(directory, fileName)
        const mimeType = mime.lookup(fullPath)
        const isDir = fs.lstatSync(fullPath).isDirectory()
        if ((typeof mimeType == "string") && mimeType.indexOf( "audio") > -1) {
            return [{path: fullPath, name : fileName}]
        } else if (isDir) {
            return scan(fullPath)
        } else {
            return []
        }
    } ))
}

const persist = (req, res) => {
    let body = [];
    req.on('data', (chunk) => {
      body.push(chunk);
    }).on('end', () => {
      body = JSON.parse(Buffer.concat(body).toString());
      // at this point, `body` has the entire request body stored in it as a string
      fs.writeFileSync(LIBRARY_FILE, JSON.stringify(body, null, 4))
      res.writeHead(200, {'Content-Type': 'application/json'});
      res.end()
    });
}

const server = http.createServer(requestListener);
server.listen(8080);



async function createWindow () {
  // session.defaultSession.webRequest.onHeadersReceived(x => console.log(x))
  // Create the browser window.
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    frame: false,

    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: true,
      webSecurity: false
    }
  })
  allowFrames(mainWindow.webContents.session)

  await loadURL(mainWindow);

  // The above is equivalent to this:
  await mainWindow.loadURL('app://tuna');
  // and load the index.html of the app.
  // mainWindow.loadFile('index.html')

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

// if you checked "fancy-settings" in extensionizr.com, uncomment this lines

// var settings = new Store("settings", {
//     "sample_setting": "This is how you use Store.js to remember values"
// });


//example of using a message handler from the inject scripts
const allowFrames = session => {
    console.log(session.webRequest)
    modifyHeaders()
    function modifyHeaders () {
        const filter = {urls: ['https://bandcamp.com/login']}
        console.log("modifyHeaders")
        // https://usamaejaz.com/bypassing-security-iframe-webextension/
        session.webRequest.onHeadersReceived(filter, (info, callback) => {
            const responseHeaders = info.responseHeaders
            responseHeaders['Content-Security-Policy'] ="frame-ancestors self app://tuna"
            console.log(responseHeaders)
            callback({responseHeaders})
        }, {
            urls: [ "<all_urls>" ], // match all pages
            types: [ "sub_frame" ] // for framing only
        }, ["blocking", "responseHeaders"]);

    }
}
