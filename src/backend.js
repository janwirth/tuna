const http = require('http');
const fs = require('fs');
const path = require('path');
const mime = require('mime-types')
const LIBRARY_FILE = './library.json'
const fetch = require('isomorphic-fetch')
const Entities = require('html-entities').AllHtmlEntities;
 
const entities = new Entities();

// extract the data encoded in the bandcamp data blob
const fetchAndSlice = async (cookie, url) => {

      // INIT
      // request bandcamp
      const data =
        await fetch(url,
                { method: 'GET'
                , headers: {Cookie: cookie}
                }
            )
      const text = await data.text()
      // extract data
      const re = /data-blob="(\{.*})"/
      const blobAndTail = text.split("data-blob=\"")[1]
      const blob = blobAndTail.split("\"></div>")[0]
      return JSON.parse(entities.decode(blob))
}

const bandcamp_init = app => async cookie => {
    console.log("bandcamp init called")
  const initData = await fetchAndSlice(cookie, "https://bandcamp.com")
  // @@ TODO FIX for some reason the part after await is called twice
  const username = initData.identities.fan.username
  // console.log(username)
  const collectionData = await fetchAndSlice(cookie, "https://bandcamp.com/" + username)
  console.log(initData)
  console.log(collectionData)
  app.ports.bandcamp_library_retrieved.send(collectionData)
}

// methods
const restore = () => {
    const data = fs.readFileSync(LIBRARY_FILE).toString()
    return JSON.parse(data)
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

// recursively scan a directory for audio files
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

const persist = model => {
  const encoded = JSON.stringify(model);
  // at this point, `body` has the entire request body stored in it as a string
  fs.writeFileSync(LIBRARY_FILE, JSON.stringify(encoded, null, 4))
}


module.exports = {persist, restore, bandcamp_init}
