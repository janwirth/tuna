// A very illegal and hacky adapter for bandcamp
const Downloader = require("./Bandcamp/Downloader")
const {fetchAndSlice} = require("./Bandcamp/help")
const Services = require("./Bandcamp/Services")
console.log(Services)

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
  app.ports.bandcamp_in_connection_opened.send(collectionData)
}

module.exports = {setupPorts}
