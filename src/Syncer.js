const fs = require("fs")
const SimpleDownloader = require('./Bandcamp/SimpleDownloader.js')
const path = require("path")
const uri2path = require('file-uri-to-path');

const setupPorts = app => {
        app.ports.syncer_out_prepare_assets.subscribe(prepareAssets(app))
        app.ports.syncer_out_copy.subscribe(({files, to}) => {
            files.map(copyFile(app)(to))
        })
    }

const prepareAssets = app => async ({cookie, items}) => {
    items.map(({track_id, params}) => {
        SimpleDownloader.with_progress(
                { on_complete: app.ports.bandcamp_simpleDownloader_in_complete.send
                , on_progress: app.ports.bandcamp_simpleDownloader_in_progress.send
                }
            )({cookie, track_id, params})
    })
}

const copyFile = app => to => async ({uri, name}) => {
    const file = uri2path(uri)
    const targetFile = path.join(to, `${name}.mp3`)
    // do not copy if file is already there
    if (fs.existsSync(targetFile)) {
        console.log('file already copied')
        app.ports.syncer_in_copy_one_complete.send(null)
    } else {
        fs.copyFile(file, targetFile, (err) => {
            if (err) {
                console.err(err)
            } else {
                app.ports.syncer_in_copy_one_complete.send(null)
            }
        })
    }
}

module.exports = {setupPorts}
