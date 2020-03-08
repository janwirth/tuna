const fetch = require('isomorphic-fetch')
const Entities = require('html-entities').AllHtmlEntities;
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
      return slice(text)
}

const slice = text => {
    // extract data
    const blobAndTail = text.split("data-blob=\"")[1]
    const blob = blobAndTail.split("\"></div>")[0]
    return JSON.parse(entities.decode(blob))
}

module.exports = {fetchAndSlice}
