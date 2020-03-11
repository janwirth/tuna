const fs = require('fs')
const pathUtil = require('path')
const mime = require('mime-types')
const mm = require('music-metadata')


// read files inside directories and return file ref
const import_ = app => async paths => {
  const files = await Promise.all(paths.map(scanPath))
  // at this point, `body` has the entire request body stored in it as a string
  const flat = flatten(files)
  console.log(flat)
  app.ports.paths_scanned.send(flat)
}

// recursively scan a directory for audio files
const scanPath = async path => {
    // is importable file?
    const lstat = fs.lstatSync(path)
    const mimeType = mime.lookup(path)
    const isAudioFile = (typeof mimeType == "string") && mimeType.indexOf( "audio") > -1
    const fileName = nameFromPath(path)
    const isNotHidden = !fileName.startsWith('.')
    // is dir
    const isDir = fs.lstatSync(path).isDirectory()
    if (isAudioFile && isNotHidden) {
        console.log('FILE', fileName)
        console.log('NAME', removeExtension(fileName))
        const isMp3 = mimeType.indexOf('mpeg') > -1
        const meta = await mm.parseFile(path)
        const name = removeExtension(fileName)
        const final =
            { ...defaultExtendedMetaData
            , path
            , name : meta.common.title || name
            , ...meta.common
            }
        console.log(final)
        console.log(meta.common)
        return [final]
    } else if (isDir) {
        return scanDir(path)
    } else {
        return []
    }
}

const defaultExtendedMetaData = {artist : "", trackNumber: null, album: "", albumartist: ""}
const flatten = arr => Array.prototype.concat(...arr)
const nameFromPath = path => path.split('/').slice(-1)[0]
const removeExtension = name => name.split('.').slice(0, -1).join('.')

const scanDir = async directory => {
    const items = fs.readdirSync(directory)
    const scanResult =
        items.map(async fileName =>
            await scanPath(pathUtil.join(directory, fileName))
        )
    return flatten(await Promise.all(scanResult))
}

module.exports = {import_, scanDir}
