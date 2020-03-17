const fs = require('fs')
const pathUtil = require('path')
const mime = require('mime-types')
const mm = require('music-metadata')
var recursive = require("recursive-readdir");
var Queue = require('better-queue');
const revisionHash = require('rev-hash');
const S = require('sanctuary')
 
const hashFile = path => {
        const file = fs.readFileSync(path)
        return revisionHash(file)
    }

const tunaDir = pathUtil.join(require('os').homedir(), '.tuna')
const ensureTunaDir = () =>
    fs.existsSync(tunaDir)
    ? console.info('not my first startup')
    : fs.mkdirSync(tunaDir, { recursive: true })

// read files inside directories and return file ref
const import_ = app => async paths => {
  const files = await Promise.all(paths.map(readAllAudioFiles))
  // at this point, `body` has the entire request body stored in it as a string
  const flat = flatten(files)
  app.ports.filesystem_in_paths_scanned.send(flat)
  readMeta(app)(flat)
}

const replaceString = S.curry3 ((what, replacement, string) =>
  string.replace (RegExp(what, 'g'), replacement)
)

// extractGenre : Meta -> Maybe String
const extractGenre = meta =>
    meta.common.genre
    && typeof meta.common.genre[0] == 'string'
    && meta.common.genre[0].trim()
    ? S.Just (meta.common.genre[0].trim() |> refineGenre)
    : S.Nothing

const log = d => {console.log(d); return d}
// refineGenre : String -> String
const refineGenre = g =>
    g
    |> replaceString("hip-hop")("hiphop")
    |> replaceString("-")(":")
    |> replaceString(" ")("")
    |> log
    |> (genre => `genre:${genre.toLowerCase()}`)

const processOne = async path => {
    const meta = await mm.parseFile(path)
    const name = removeExtension(nameFromPath(path))
    const bpmTag =
        meta.common.bpm
        ? S.Just (`bpm:${meta.common.bpm}`)
        : S.Nothing
    const genreTag =
        meta
        |> extractGenre
    const tags =
        [genreTag, bpmTag]
        |> S.justs
        |> S.unwords
    const final =
        { ...defaultExtendedMetaData
        , path
        , name : meta.common.title || name
        , ...meta.common
        , track : {no: null}
        , tags : tags
        , hash : hashFile(path)
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

module.exports = {import_, getMime, ensureTunaDir, tunaDir}
