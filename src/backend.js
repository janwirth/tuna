const LIBRARY_FILE = './library.json'
const fetch = require('isomorphic-fetch')
const Entities = require('html-entities').AllHtmlEntities;
const fs = require('fs')
 
const entities = new Entities();

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

const bandcamp_init = app => async cookie => {
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

// methods
const restore = () => {
    const data = fs.readFileSync(LIBRARY_FILE).toString()
    return JSON.parse(data)
}

const persist = model => {
  const encoded = JSON.stringify(model);
  // at this point, `body` has the entire request body stored in it as a string
  fs.writeFileSync(LIBRARY_FILE, JSON.stringify(encoded, null, 4))
}


module.exports = {persist, restore, bandcamp_init}
