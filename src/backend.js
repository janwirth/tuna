const http = require('http');

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
