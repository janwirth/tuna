const fetch = require('isomorphic-fetch')
const Entities = require('html-entities').AllHtmlEntities;
const entities = new Entities();
const fs = require("fs")

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
      // extract data
      const re = /data-blob="(\{.*})"/
      const blobAndTail = text.split("data-blob=\"")[1]
      const blob = blobAndTail.split("\"></div>")[0]
      return JSON.parse(entities.decode(blob))
}

const connect = app => async cookie => {
    console.log("bandcamp init called")
  const initData = await fetchAndSlice(cookie, "https://bandcamp.com")
  // @@ TODO FIX for some reason the part after await is called twice
  const username = initData.identities.fan.username
  // console.log(username)
  const collectionData = await fetchAndSlice(cookie, "https://bandcamp.com/" + username)
  console.log(initData)
  console.log(collectionData)
  app.ports.bandcamp_library_retrieved.send(collectionData)
}
const download = app => async ([cookie, purchase_id, download_url]) => {
    console.log(cookie, purchase_id, download_url)
}
module.exports = {connect, download}
