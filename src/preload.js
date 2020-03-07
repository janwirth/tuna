const {persist, restore, bandcamp_init} = require("./backend")
const {import_} = require("./fileSystem")
const {register} = require("./custom-elements")
const {Elm} = require("../elm-stuff/elm.js")

register()

// All of the Node.js APIs are available in the preload process.
// It has the same sandbox as a Chrome extension.
window.addEventListener('DOMContentLoaded', () => {


  const replaceText = (selector, text) => {
    const element = document.getElementById(selector)
    if (element) element.innerText = text
  }

  for (const type of ['chrome', 'node', 'electron']) {
    replaceText(`${type}-version`, process.versions[type])
  }
  console.log('setting data transfer item')
  window.DataTransferItem.prototype.__defineGetter__("entry", function() {
      const entry = this.webkitGetAsEntry()
      console.log(entry)
      return entry;
  });
})

document.addEventListener('DOMContentLoaded', () => {
    const flags = JSON.parse(restore())
    console.log(flags)
    const app = Elm.Main.init({flags})
    app.ports.scan_directories.subscribe(import_(app))
    app.ports.persist_.subscribe(persist)
    app.ports.bandcamp_init_request.subscribe(bandcamp_init(app))
})
