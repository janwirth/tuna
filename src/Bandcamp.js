// A very illegal and hacky adapter for bandcamp
const Downloader = require("./Bandcamp/Downloader")
const {fetchAndSlice} = require("./Bandcamp/help")
const Services = require("./Bandcamp/Services")

const setupPorts = app => {
    // connect bandcamp
    app.ports.bandcamp_out_connection_requested.subscribe(connect(app))
    Downloader.setupPorts(app)
    Services.register()
}

const connect = app => async cookie => {
  const initData = await fetchAndSlice(cookie, "https://bandcamp.com")
  // @@ TODO FIX for some reason the part after await is called twice
  const username = initData.identities.fan.username
  const collectionData = await fetchAndSlice(cookie, "https://bandcamp.com/" + username)

  const moreResponse = await getRest(cookie, initData.identities.fan.id, collectionData.collection_data.last_token)
  const more = await moreResponse.json()
  const redownload_urls = {...collectionData.collection_data.redownload_urls, ...more.redownload_urls}
  const items = [...Object.values(collectionData.item_cache.wishlist), ...Object.values(collectionData.item_cache.collection), ...more.items]
  const tracklists =
    { ...collectionData.tracklists.wishlist
    , ...collectionData.tracklists.collection
    , ...more.tracklists
    }
  console.log(tracklists)
  console.log(items)
  // add trackslists
  items.forEach(i => {
      i.tracks = tracklists[i.tralbum_type + i.item_id] || tracklists["p" + i.item_id] || []
  })
  const relevant = {items, redownload_urls}
  console.log(relevant.items)
  app.ports.bandcamp_in_connection_opened.send(relevant)
}

const getRest = (cookie, fan_id, older_than_token) => {
        const body =
            JSON.stringify({ fan_id
            , older_than_token
            , "count":10000
            })
        const headers = {Cookie: cookie}
        return fetch("https://bandcamp.com/api/fancollection/1/collection_items",
            { body
            , method:"POST"
            , headers
            });
    }
module.exports = {setupPorts}
