const Storage = require("./backend")
const Bandcamp = require("./bandcamp")
const FileSystem = require("./fileSystem")
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
    // init and connect persistence layer
    const flags = JSON.parse(Storage.restore())
    const app = Elm.Main.init({flags})
    app.ports.persist_.subscribe(Storage.persist)
    // connect file system access
    app.ports.scan_directories.subscribe(FileSystem.import_(app))
    // connect bandcamp
    app.ports.bandcamp_init_request.subscribe(Bandcamp.connect(app))
    app.ports.bandcamp_download_request.subscribe(Bandcamp.download(app))
    app.ports.bandcamp_import.subscribe(Bandcamp.import_(app))
})
