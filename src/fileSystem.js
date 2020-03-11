const fs = require('fs')
const pathUtil = require('path')
const mime = require('mime-types')

// read files inside directories and return file ref
const import_ = app => async paths => {
  const files = Array.prototype.concat(...paths.map(scanPath))
  // at this point, `body` has the entire request body stored in it as a string
  app.ports.paths_scanned.send(files)
}

// recursively scan a directory for audio files
const scanPath = path => {
    // is importable file?
    const lstat = fs.lstatSync(path)
    const mimeType = mime.lookup(path)
    const isAudioFile = (typeof mimeType == "string") && mimeType.indexOf( "audio") > -1
    const fileName = nameFromPath(path)
    console.log(fileName, path)
    const isNotHidden = !fileName.startsWith('.')
    // is dir
    const isDir = fs.lstatSync(path).isDirectory()
    if (isAudioFile && isNotHidden) {
        console.log('FILE', fileName)
        console.log('NAME', removeExtension(fileName))
        return [{path: path, name : removeExtension(fileName)}]
    } else if (isDir) {
        return scanDir(path)
    } else {
        return []
    }
}
const flatten = arr => Array.prototype.concat(...arr)
const nameFromPath = path => path.split('/').slice(-1)[0]
const removeExtension = name => name.split('.').slice(0, -1).join('.')

const scanDir = directory => {
    const items = fs.readdirSync(directory)
    const scanResult =
        items.map(fileName =>
            scanPath(pathUtil.join(directory, fileName))
        )
    return flatten(scanResult)
}

module.exports = {import_, scanDir}
