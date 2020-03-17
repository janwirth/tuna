const mm = require('music-metadata')
const revisionHash = require('rev-hash');
const S = require('sanctuary')
const fs = require('fs')


// extractGenre : Meta -> Maybe String
const extractGenre = meta =>
    meta.common.genre
    && typeof meta.common.genre[0] === 'string'
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
    |> (genre => `genre:${genre.toLowerCase()}`)

// makeQuality : Meta -> Maybe String
const makeQuality = meta =>
    meta.format.bitrate > 500E3
    ? 'quality:excellent'
    : meta.format.bitrate > 200E3
    ? 'quality:good'
    : meta.format.bitrate > 150E3
    ? 'quality:okay'
    : 'quality:bad'

const readOne = async path => {
    const meta = await mm.parseFile(path)
    const name = removeExtension(nameFromPath(path))
    const qualityTag =
        makeQuality(meta)
        |> S.Just
    const bpmTag =
        meta.common.bpm
        ? S.Just (`bpm:${meta.common.bpm}`)
        : S.Nothing
    const genreTag = extractGenre(meta)
    log(meta)
    const tags =
        [genreTag, bpmTag, qualityTag]
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
        , duration : meta.format.duration |> Math.round
        , bitrate : meta.format.bitrate
        }
    return final
}

 
const hashFile = path => {
        const file = fs.readFileSync(path)
        return revisionHash(file)
    }


const nameFromPath = path => path.split('/').slice(-1)[0]

module.exports = {readOne, nameFromPath}

// HELPERS
const defaultExtendedMetaData = {artist : "", trackNumber: null, album: "", albumartist: ""}
const removeExtension = name => name.split('.').slice(0, -1).join('.')

const replaceString = S.curry3 ((what, replacement, string) =>
  string.replace (RegExp(what, 'g'), replacement)
)
