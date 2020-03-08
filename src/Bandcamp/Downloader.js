const { createWriteStream } =  require('fs')
const request =  require('request')
const progress =  require('request-progress')
const fs = require('fs')
const path = require('path')
const DecompressZip = require('decompress-zip');
const rimraf = require('rimraf-promise')
const {fetchAndSlice} = require('./help')
const FileSystem = require('../fileSystem')
// Elm orchestrates all these functions.
const rootPath = require('electron-root-path').rootPath;
const BANDCAMP_DOWNLOAD_DIR = "bandcamp"

// fetch the asset URl from bandcamp
const get_asset_url = async (cookie, encode_url) => {
      const {url} =
        await fetch(encode_url,
                { method: 'GET'
                , headers: {Cookie: cookie}
                }
            )
      return url
    }

const setupPorts = app => {
    app.ports.bandcamp_downloader_out_formatter_url_requested
        .subscribe(formatter_url_requested(app))
    app.ports.bandcamp_downloader_out_asset_url_requested
        .subscribe(asset_url_requested(app))
    app.ports.bandcamp_downloader_out_download_initiated
        .subscribe(download_initiated(app))
    app.ports.bandcamp_downloader_out_unzip_initiated
        .subscribe(unzip_initiated(app))
    app.ports.bandcamp_downloader_out_scan_started
        .subscribe(scan_started(app))
}

const formatter_url_requested = app => async ({cookie, purchase_id, download_page_url}) =>
    {
        // has it been downloaded before?
        if (already_downloaded(purchase_id)) {
            app.ports.bandcamp_downloader_in_download_completed.send(purchase_id)
            return
        }
        const data = await fetchAndSlice(cookie, download_page_url)
        const mp3Download = data.download_items[0].downloads['mp3-v0']
        const formatter_url = mp3Download.url
        app.ports.bandcamp_downloader_in_formatter_url_retrieved.send([purchase_id, formatter_url])
    }

const asset_url_requested = app => async ({cookie, purchase_id, formatter_url}) =>
    {
        const asset_url = await get_asset_url(cookie, formatter_url)
        app.ports.bandcamp_downloader_in_asset_url_retrieved.send([purchase_id, asset_url])
    }

const download_initiated = app => params =>
    with_progress(
        params,
        { on_complete : app.ports.bandcamp_downloader_in_download_completed.send
            , on_progress : app.ports.bandcamp_downloader_in_download_progressed.send
        }
    )

const unzip_initiated = app => purchase_id =>
    unzip(purchase_id
        , app.ports.bandcamp_downloader_in_files_extracted.send
        )

const scan_started = app => purchase_id =>
    {
        const target_dir = unzipped_path(purchase_id)
        const files = FileSystem.scanDir(target_dir)
        app.ports.bandcamp_downloader_in_files_scanned
            .send([purchase_id, files])
    }


// ensure bandcamp directory exists
if (!fs.existsSync(BANDCAMP_DOWNLOAD_DIR)){
    fs.mkdirSync(BANDCAMP_DOWNLOAD_DIR);
}
const tempfile_path = purchase_id =>
        path.join(
              rootPath
            , BANDCAMP_DOWNLOAD_DIR
            , `${purchase_id}.downloading.zip`
            )

const complete_file_path = purchase_id =>
        path.join(
            BANDCAMP_DOWNLOAD_DIR
            , `${purchase_id}.zip`
            )

const unzipped_path = purchase_id =>
        path.join(
              rootPath
            , BANDCAMP_DOWNLOAD_DIR
            , `${purchase_id}`
            )

const already_downloaded = purchase_id =>
    fs.existsSync(complete_file_path(purchase_id))

const with_progress = ({asset_url, purchase_id}, {on_complete, on_progress}) => {
    var has_error = false
    // determine where the file needs to be downloaded to
    const tempfile = tempfile_path(purchase_id)
    // clean unfinished downloads
    fs.existsSync(tempfile) && fs.unlinkSync(tempfile)
    // start download
    progress(request(asset_url))
     .on('progress', state => {
          const percent = Math.round((state.percent || 0) * 100)
          on_progress([purchase_id, percent])
      })
      .on('error', err => {console.log(err); has_error = true})
      .on('end', () => {
          // remove `.downloading` suffix
          if (!has_error) {
              fs.renameSync( tempfile_path(purchase_id) , complete_file_path(purchase_id))
              on_complete(purchase_id)
          }
      })
      .pipe(createWriteStream(tempfile))
}

const unzip = (purchase_id, on_complete) => {
    const target = unzipped_path(purchase_id)
    rimraf(target).catch(() => null).then(() => {
        const unzipper = new DecompressZip(complete_file_path(purchase_id))
        unzipper.on('error', function (err) {
            console.log(err)
            console.log('Caught an error');
        });
         
        unzipper.on('extract', function (log) {
            on_complete(purchase_id)
        });
         
        unzipper.on('progress', function (fileIndex, fileCount) {
            console.log('Extracted file ' + (fileIndex + 1) + ' of ' + fileCount);
        });
         
        unzipper.extract({
            path: target,
            filter: function (file) {
                return file.type !== "SymbolicLink";
            }
        });
    })
}

module.exports = {setupPorts}
