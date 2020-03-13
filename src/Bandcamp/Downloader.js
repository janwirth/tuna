const { createWriteStream } =  require('fs')
const request =  require('request')
const progress =  require('request-progress')
const fs = require('fs')
const FileSystem = require('../FileSystem')
const path = require('path')
const DecompressZip = require('decompress-zip');
const rimraf = require('rimraf-promise')
const {fetchAndSlice} = require('./help')
// Elm orchestrates all these functions.
const rootPath = require('electron-root-path').rootPath;
const BANDCAMP_DOWNLOAD_DIR = "bandcamp"

// fetch the asset URl from bandcamp
const get_asset_url = async (cookie, encode_url) => {
      const res =
        await fetch(encode_url,
                { method: 'GET'
                , headers: {Cookie: cookie}
                }
            )
      return res
    }

const setupPorts = app => {
    app.ports.bandcamp_downloader_out_download_initiated
        .subscribe(download_initiated(app))
    app.ports.bandcamp_downloader_out_unzip_initiated
        .subscribe(unzip_initiated(app))
    app.ports.bandcamp_downloader_out_scan_started
        .subscribe(scan_started(app))
}

const download_initiated = app => params =>
    with_progress(
        params,
        { on_complete : app.ports.bandcamp_downloader_in_download_completed.send
            , on_progress : app.ports.bandcamp_downloader_in_download_progressed.send
        }
    )

const unzip_initiated = app => params =>
    unzip({on_complete: app.ports.bandcamp_downloader_in_files_extracted.send, ...params})

const scan_started = app => ({item_id, item_type}) =>
    {
        const target_dir = unzipped_path(item_id, item_type)
        console.log(target_dir)
        FileSystem.import_(app)([target_dir])
        // app.ports.bandcamp_downloader_in_files_scanned.send(item_id)
    }


// ensure bandcamp directory exists
if (!fs.existsSync(BANDCAMP_DOWNLOAD_DIR)){
    fs.mkdirSync(BANDCAMP_DOWNLOAD_DIR);
}
const tempfile_path = item_id =>
        path.join(
              rootPath
            , BANDCAMP_DOWNLOAD_DIR
            , `${item_id}.downloading`
            )

const complete_file_path = (item_id, item_type = "zip") =>
        path.join(
            BANDCAMP_DOWNLOAD_DIR
            , `${item_id}.${item_type}`
            )

const unzipped_path = (item_id, item_type = "zip") =>
        item_type == 'zip'
            ? path.join(
                  rootPath
                , BANDCAMP_DOWNLOAD_DIR
                , `${item_id}`
                )
            : path.join(rootPath, complete_file_path(item_id, item_type))


const already_downloaded = (item_id, item_type) =>
    fs.existsSync(complete_file_path(item_id, item_type))

const with_progress = ({asset_url, item_id, item_type}, {on_complete, on_progress}) => {
    if (!(asset_url && item_id && item_type)) {
        throw '{asset_url, item_id, item_type} required'
    }
    if (already_downloaded(item_id, item_type)) {
        on_complete(item_id)
        return
    }
    var has_error = false
    // determine where the file needs to be downloaded to
    const tempfile = tempfile_path(item_id)
    // clean unfinished downloads
    fs.existsSync(tempfile) && fs.unlinkSync(tempfile)
    // start download
    progress(request(asset_url))
     .on('progress', state => {
          const percent = Math.round((state.percent || 0) * 100)
          on_progress([item_id, percent])
      })
      .on('error', err => {console.log(err); has_error = true})
      .on('end', () => {
          // remove `.downloading` suffix
          if (!has_error) {
              fs.renameSync( tempfile_path(item_id) , complete_file_path(item_id, item_type))
              on_complete(item_id)
          }
      })
      .pipe(createWriteStream(tempfile))
}

const unzip = ({item_id, on_complete, item_type}) => {
    const target = unzipped_path(item_id)
    if (item_type == "mp3") {
        on_complete(item_id)
        return
    }
    rimraf(target).catch(() => null).then(() => {
        const unzipper = new DecompressZip(complete_file_path(item_id))
        unzipper.on('error', function (err) {
            console.warn('Caught an error');
        });
         
        unzipper.on('extract', function (log) {
            on_complete(item_id)
        });
         
        unzipper.on('progress', function (fileIndex, fileCount) {
            // console.log('Extracted file ' + (fileIndex + 1) + ' of ' + fileCount);
        });
         
        unzipper.extract({
            path: target,
            filter: function (file) {
                return file.type !== "SymbolicLink";
            }
        });
    })
}

module.exports = {setupPorts, complete_file_path}
