const { createWriteStream } =  require('fs')
const request =  require('request')
const progress =  require('request-progress')
const fs = require('fs')
const path = require('path')
const DecompressZip = require('decompress-zip');
const rimraf = require('rimraf-promise')

const BANDCAMP_DOWNLOAD_DIR = "bandcamp"

// ensure bandcamp directory exists
if (!fs.existsSync(BANDCAMP_DOWNLOAD_DIR)){
    fs.mkdirSync(BANDCAMP_DOWNLOAD_DIR);
}
const tempfile_path = purchase_id =>
        path.join(
            BANDCAMP_DOWNLOAD_DIR
            , `${purchase_id}.downloading.zip`
            )

const complete_file_path = purchase_id =>
        path.join(
            BANDCAMP_DOWNLOAD_DIR
            , `${purchase_id}.zip`
            )

const unzipped_path = purchase_id =>
        path.join(
            BANDCAMP_DOWNLOAD_DIR
            , `${purchase_id}`
            )

const absolute_target = purchase_id =>
        path.join(__dirname, "..", unzipped_path(purchase_id))

const already_downloaded = purchase_id =>
    fs.existsSync(complete_file_path(purchase_id))

const with_progress = (purchase_id, url, cb) => {
    // has it been downloaded before?
    if (already_downloaded(purchase_id)) {
        complete_download(purchase_id)
        return
    }
    // determine where the file needs to be downloaded to
    const tempfile = tempfile_path(purchase_id)
    // clean unfinished downloads
    fs.existsSync(tempfile) && fs.unlinkSync(tempfile)
    // start download
    progress(request(url))
     .on('progress', state => {
         cb(state)
      })
      .on('error', err => console.log(err))
      .on('end', () => complete_download(purchase_id))
      .pipe(createWriteStream(tempfile))
}

// mark the file as complete and extract the zip
complete_download = purchase_id =>
    {
        fs.rename(
            tempfile_path(purchase_id)
        , complete_file_path(purchase_id)
        , (err) => {
          if (err) throw err;
          console.log('Rename complete!');
        });
        unzip(purchase_id)
    }

const unzip = async purchase_id => {
    const target = unzipped_path(purchase_id)
    fs.existsSync(target) && await rimraf(target)
    const unzipper = new DecompressZip(complete_file_path(purchase_id))
    unzipper.on('error', function (err) {
        console.log(err)
        console.log('Caught an error');
    });
     
    unzipper.on('extract', function (log) {
        console.log('Finished extracting');
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
}

module.exports = {with_progress, already_downloaded, unzip, absolute_target}
