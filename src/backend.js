const LIBRARY_FILE = './library.json'
const fs = require('fs')

// methods
const restore = () => {
    if (fs.existsSync(LIBRARY_FILE)) {
        const data = fs.readFileSync(LIBRARY_FILE).toString()
        return JSON.parse(data)
    } else {
        return null
    }
}

const persist = model => {
  const encoded = JSON.stringify(model);
  // at this point, `body` has the entire request body stored in it as a string
  fs.writeFileSync(LIBRARY_FILE, JSON.stringify(encoded, null, 4))
}


module.exports = {persist, restore}
