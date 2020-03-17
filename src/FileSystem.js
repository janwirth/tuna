const fs = require('fs')
const pathUtil = require('path')
const mime = require('mime-types')
const recursive = require("recursive-readdir");
const Queue = require('better-queue');
const MetaData = require('./MetaData')

const tunaDir = pathUtil.join(require('os').homedir(), '.tuna')
const ensureTunaDir = () =>
    fs.existsSync(tunaDir)
    ? console.log('not my first startup')
    : fs.mkdirSync(tunaDir, { recursive: true })

// read files inside directories and return file ref
const import_ = app => async paths => {
  const files = await Promise.all(paths.map(readAllAudioFiles))
  // at this point, `body` has the entire request body stored in it as a string
  const flat = flatten(files)
  app.ports.filesystem_in_paths_scanned.send(flat)
  readMeta(app)(flat)
}


const readMeta = app => async files => {

    var q = new Queue(async (paths, cb) => {
        const entries = await Promise.all(paths.map(MetaData.readOne))
        app.ports.filesystem_in_files_parsed.send(entries)
        cb(null, entries);
    }, {batchSize: 100, concurrent: 5})
    files.forEach(file => q.push(file))

}

const readAllAudioFiles = path => new Promise ((resolve, reject) => {
    const ignore = (file, stat) => {
        if (stat.isDirectory()) {
            false
        } else {
            const fileName = MetaData.nameFromPath(file)
            const isHidden = fileName.startsWith('.')
            const mimeType = mime.lookup(file)
            const isAudioFile = (typeof mimeType == "string") && mimeType.indexOf( "audio") > -1
            const shouldIgnore = isHidden || !isAudioFile
            return shouldIgnore
        }
    }
    if (ignore(path, fs.lstatSync(path))) {
        resolve([])
    } else if (fs.lstatSync(path).isFile())(
        resolve([path])
    )
    recursive(path, [ignore], function (err, files) {
      resolve(files);
    });
})

const getMime = file => mime.lookup(file)
const flatten = arr => Array.prototype.concat(...arr)

module.exports = {import_, getMime, ensureTunaDir, tunaDir}
