const Storage = require("./backend")
const Bandcamp = require("./Bandcamp")
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

// makeSeed : () => string
const makeSeed = () => {

    const generated_seed = new Uint32Array(10);
    window.crypto.getRandomValues(generated_seed);
    const [seed, ...seed_extension] = generated_seed
    return {seed, seed_extension}
}

document.addEventListener('DOMContentLoaded', () => {

    // init and connect persistence layer
    const seed = makeSeed()
    console.log(seed)
    const restored = JSON.parse(Storage.restore())
    const flags = {restored, ...seed}
    const app = Elm.Main.init({flags})
    console.log(flags)
    console.log(flags.restored)
    app.ports.persist_.subscribe(Storage.persist)
    // connect file system access
    app.ports.scan_directories.subscribe(FileSystem.import_(app))
    Bandcamp.setupPorts(app)
})
