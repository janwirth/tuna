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
      const res =
        await fetch(encode_url,
                { method: 'GET'
                , headers: {Cookie: cookie}
                }
            )
      return res
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

const formatter_url_requested = app => async ({cookie, item_id, download_page_url}) =>
    {
        // has it been downloaded before?
        if (already_downloaded(item_id)) {
            app.ports.bandcamp_downloader_in_download_completed.send(item_id)
            return
        }
        const data = await fetchAndSlice(cookie, download_page_url)
        console.log(data)
        const mp3Download = data.download_items[0].downloads['mp3-v0']
        const formatter_url = mp3Download.url
        const msg = [item_id, formatter_url]
        console.log(msg)
        app.ports.bandcamp_downloader_in_formatter_url_retrieved.send(msg)
    }

const asset_url_requested = app => async ({cookie, item_id, formatter_url}) =>
    {
        console.log('formatter in curl', formatter_url)
        const {url, redirected} = await get_asset_url(cookie, formatter_url)
        console.log('asset_url', url)
        console.log(app.ports)
        if (redirected) {
            app.ports.bandcamp_downloader_in_download_failed.send(item_id)
        } else {
            app.ports.bandcamp_downloader_in_asset_url_retrieved.send([item_id, url])
        }
    }

const download_initiated = app => params =>
    with_progress(
        params,
        { on_complete : app.ports.bandcamp_downloader_in_download_completed.send
            , on_progress : app.ports.bandcamp_downloader_in_download_progressed.send
        }
    )

const unzip_initiated = app => item_id =>
    unzip(item_id
        , app.ports.bandcamp_downloader_in_files_extracted.send
        )

const scan_started = app => item_id =>
    {
        const target_dir = unzipped_path(item_id)
        const files = FileSystem.scanDir(target_dir)
        app.ports.bandcamp_downloader_in_files_scanned
            .send([item_id, files])
    }


// ensure bandcamp directory exists
if (!fs.existsSync(BANDCAMP_DOWNLOAD_DIR)){
    fs.mkdirSync(BANDCAMP_DOWNLOAD_DIR);
}
const tempfile_path = item_id =>
        path.join(
              rootPath
            , BANDCAMP_DOWNLOAD_DIR
            , `${item_id}.downloading.zip`
            )

const complete_file_path = item_id =>
        path.join(
            BANDCAMP_DOWNLOAD_DIR
            , `${item_id}.zip`
            )

const unzipped_path = item_id =>
        path.join(
              rootPath
            , BANDCAMP_DOWNLOAD_DIR
            , `${item_id}`
            )

const already_downloaded = item_id =>
    fs.existsSync(complete_file_path(item_id))

const with_progress = ({asset_url, item_id}, {on_complete, on_progress}) => {
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
              fs.renameSync( tempfile_path(item_id) , complete_file_path(item_id))
              on_complete(item_id)
          }
      })
      .pipe(createWriteStream(tempfile))
}

const unzip = (item_id, on_complete) => {
    const target = unzipped_path(item_id)
    rimraf(target).catch(() => null).then(() => {
        const unzipper = new DecompressZip(complete_file_path(item_id))
        unzipper.on('error', function (err) {
            console.log(err)
            console.log('Caught an error');
        });
         
        unzipper.on('extract', function (log) {
            on_complete(item_id)
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
