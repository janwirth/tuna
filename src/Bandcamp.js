// A very illegal and hacky adapter for bandcamp
const Downloader = require("./Bandcamp/Downloader")
const {fetchAndSlice} = require("./Bandcamp/help")

const setupPorts = app => {
    // connect bandcamp
    app.ports.bandcamp_out_connection_requested.subscribe(connect(app))
    Downloader.setupPorts(app)
}

const connect = app => async cookie => {
  const initData = await fetchAndSlice(cookie, "https://bandcamp.com")
  // @@ TODO FIX for some reason the part after await is called twice
  const username = initData.identities.fan.username
  const collectionData = await fetchAndSlice(cookie, "https://bandcamp.com/" + username)
  console.log(collectionData)
  app.ports.bandcamp_in_connection_opened.send(collectionData)
}

module.exports = {setupPorts}
