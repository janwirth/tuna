const Storage = require("./backend")
const Bandcamp = require("./Bandcamp")
const FileSystem = require("./FileSystem")
const CustomElements = require("./custom-elements")
const {Elm} = require("../elm-stuff/elm.js")
const fileUrl = require("file-url")
const Syncer = require("./Syncer")

CustomElements.register()

// All of the Node.js APIs are available in the preload process.
// It has the same sandbox as a Chrome extension.
window.addEventListener('DOMContentLoaded', () => {

  // log environment
  for (const type of ['chrome', 'node', 'electron']) {
    console.log(`${type}-version`, process.versions[type])
  }


  // monkey patch file drop API
  window.DataTransferItem.prototype.__defineGetter__
    ( "entry"
    , () =>  this.webkitGetAsEntry()
    )

  // init and connect persistence layer
  const seed = makeSeed()
  const restored = Storage.restore()
  const rootUrl = fileUrl(FileSystem.tunaDir)
  const flags = {restored, ...seed, rootUrl}
  const app = Elm.Main.init({flags, node : document.getElementById('app')})
  app.ports.persist_.subscribe(Storage.persist)
  // connect file system access
  app.ports.scan_paths.subscribe(FileSystem.import_(app))
  Bandcamp.setupPorts(app)
  Syncer.setupPorts(app)
})

// makeSeed : () => string
const makeSeed = () => {

    const generated_seed = new Uint32Array(10);
    window.crypto.getRandomValues(generated_seed);
    const [seed, ...seed_extension] = generated_seed
    return {seed, seed_extension}
}
