const fs = require('fs')
const pathUtil = require('path')
const mime = require('mime-types')
const mm = require('music-metadata')
var recursive = require("recursive-readdir");
var Queue = require('better-queue');


// read files inside directories and return file ref
const import_ = app => async paths => {
  const files = await Promise.all(paths.map(readAllAudioFiles))
  // at this point, `body` has the entire request body stored in it as a string
  const flat = flatten(files)
  app.ports.filesystem_in_paths_scanned.send(flat)
  readMeta(app)(flat)
}

const processOne = async path => {
    const meta = await mm.parseFile(path)
    const name = removeExtension(nameFromPath(path))
    const tags = meta.common.genre && meta.common.genre[0] || ""
    const final =
        { ...defaultExtendedMetaData
        , path
        , name : meta.common.title || name
        , ...meta.common
        , track : {no: null}
        , tags
        }
    return final
}

const readMeta = app => async files => {

    var q = new Queue(async (paths, cb) => {
        const entries = await Promise.all(paths.map(processOne))
        app.ports.filesystem_in_files_parsed.send(entries)
        cb(null, entries);
    }, {batchSize: 100, concurrent: 5})
    files.forEach(file => q.push(file))

}

// HELPERS
const defaultExtendedMetaData = {artist : "", trackNumber: null, album: "", albumartist: ""}
const flatten = arr => Array.prototype.concat(...arr)
const nameFromPath = path => path.split('/').slice(-1)[0]
const removeExtension = name => name.split('.').slice(0, -1).join('.')

const readAllAudioFiles = path => new Promise ((resolve, reject) => {
    const ignore = (file, stat) => {
        if (stat.isDirectory()) {
            false
        } else {
            const fileName = nameFromPath(file)
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

module.exports = {import_, getMime}
