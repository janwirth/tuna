// A very illegal and hacky adapter for bandcamp
const fetch = require('isomorphic-fetch')
const Entities = require('html-entities').AllHtmlEntities;
const entities = new Entities();
const fs = require("fs")
const Downloader = require("./downloader")

// extract the data encoded in the bandcamp data blob
const fetchAndSlice = async (cookie, url) => {

      // INIT
      // request bandcamp
      const data =
        await fetch(url,
                { method: 'GET'
                , headers: {Cookie: cookie}
                }
            )
      const text = await data.text()
      return slice(text)
}
const slice = text => {
    // extract data
    const blobAndTail = text.split("data-blob=\"")[1]
    const blob = blobAndTail.split("\"></div>")[0]
    return JSON.parse(entities.decode(blob))
}

const connect = app => async cookie => {
  const initData = await fetchAndSlice(cookie, "https://bandcamp.com")
  // @@ TODO FIX for some reason the part after await is called twice
  const username = initData.identities.fan.username
  const collectionData = await fetchAndSlice(cookie, "https://bandcamp.com/" + username)
  app.ports.bandcamp_library_retrieved.send(collectionData)
}

// fetch the asset from bandcamp servers and unzip
const download = app => async ([cookie, purchase_id, download_url]) => {
    if (!Downloader.already_downloaded(purchase_id)) {
        const data = await fetchAndSlice(cookie, download_url)
        const mp3Download = data.download_items[0].downloads['mp3-v0']
        const asset_url = await get_asset_url(cookie, mp3Download.url)
        Downloader
            .with_progress(purchase_id, asset_url, state => console.log('got it', state))
    } else {
        Downloader
            .unzip(purchase_id)
    }
}
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



module.exports = {connect, download}
