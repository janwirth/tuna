const fs = require('fs')
const path = require('path')
const mime = require('mime-types')

// read files inside directories and return file ref
const import_ = app => async directories => {
  const files = Array.prototype.concat(...directories.map(scanDir))
  // at this point, `body` has the entire request body stored in it as a string
  app.ports.directories_scanned.send(files)
}

// recursively scan a directory for audio files
const scanDir = directory => {
    return Array.prototype.concat(...fs.readdirSync(directory).map(fileName => {
        const fullPath = path.join(directory, fileName)
        const mimeType = mime.lookup(fullPath)
        const isDir = fs.lstatSync(fullPath).isDirectory()
        const isAudioFile = (typeof mimeType == "string") && mimeType.indexOf( "audio") > -1
        const isNotHidden = !fileName.startsWith('.')
        if (isAudioFile && isNotHidden) {
            return [{path: fullPath, name : fileName}]
        } else if (isDir) {
            return scanDir(fullPath)
        } else {
            return []
        }
    } ))
}

module.exports = {import_, scanDir}
