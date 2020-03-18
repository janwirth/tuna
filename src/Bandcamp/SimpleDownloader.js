const progress =  require('request-progress')
const request =  require('request')
const { createWriteStream } =  require('fs')
const path = require('path')
const fs = require('fs')
const fetch = require('isomorphic-fetch')
const Downloader = require('./Downloader')
const TARGET_DIR = path.join(Downloader.BANDCAMP_DOWNLOAD_DIR, "tracks")
const { shell } = require('electron')

const setupPorts = app => {
    app.ports.bandcamp_simpleDownloader_out_request
        .subscribe(with_progress(
            { on_complete: app.ports.bandcamp_simpleDownloader_in_complete.send
            , on_progress: app.ports.bandcamp_simpleDownloader_in_progress.send
            }
        ))
}

if (!fs.existsSync(TARGET_DIR)){
    fs.mkdirSync(TARGET_DIR);
}


const with_progress = ({on_complete, on_progress}) => async ({url, track_id, cookie}) => {
    console.log(url)
    var has_error = false
    console.log('starting download', track_id, url, cookie)
    const targetFile = path.join(TARGET_DIR, `${track_id}.mp3`)

    const options = {
      uri: url,
      headers: {
        'Cookie': cookie
      }
    };
    console.log(options)
    progress(request(options))
     .on('progress', state => {
          const percent = Math.round((state.percent || 0) * 100)
          on_progress({percent, track_id})
      })
      .on('error', err => {console.log(err); has_error = true})
      .on('end', () => {
          // remove `.downloading` suffix
          if (!has_error) {
              // shell.showItemInFolder(targetFile)
              on_complete(track_id)
          }
      })
      .pipe(createWriteStream(targetFile))
}

module.exports = {setupPorts, with_progress}
