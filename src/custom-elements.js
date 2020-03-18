const electron = require('electron')
console.log(electron)

function register () {
    registerAudio()
    registerDirectoryPicker()
}
function registerDirectoryPicker () {
    class DirectoryPicker extends HTMLElement {
        constructor() {
            super()
        }
        connectedCallback() {
            const dialog = electron.remote.dialog
            this.addEventListener('click', () => {
                dialog.showOpenDialog(electron.remote.getCurrentWindow (), {
                  properties: ['openDirectory']
                }).then(result => {
                    console.log(result)
                  console.log(result.canceled)
                  console.log(result.filePaths)
                  if (result.filePaths.length > 0) {
                      const directory = result.filePaths[0]
                      const picked = new CustomEvent('choosedirectory', {detail: {directory}})
                      this.dispatchEvent(picked)
                  }
                }).catch(err => {
                  console.log(err)
                })
            })
        }
    }
    customElements.define('directory-picker', DirectoryPicker)
}

function registerAudio () {
    class AudioPlayer extends HTMLElement {
        constructor() {
            super()
            const audio = document.createElement('audio')
            this.audio = audio
        }
        connectedCallback() {
            this.audio.controls = true
            this.audio.style.width = "100%"
            // react to props
            this.appendChild(this.audio)
            if (this.src) {
                applyNewSrc(this, 'src', this.src)
            }
            if (this.playing) {
                this.audio.play()
            }
            this.audio.addEventListener('play', ev => this.dispatchEvent(new Event('play')))
            this.audio.addEventListener('pause', ev => this.dispatchEvent(new Event(ev.target.ended ? 'end' : 'pause')))
        }

      // Monitor the 'name' attribute for changes.
      static get observedAttributes() {return ['name', 'src', 'playing']; }

      // Respond to attribute changes.
      attributeChangedCallback(attr, oldValue, newValue) {
        applyNewSrc(this, attr, newValue)
        if (attr === 'playing' && newValue === "true" && this.audio) {
            if (newValue) {
                this.audio.play()
            } else {
                this.audio.pause()
            }
        }
      }
    }
    customElements.define('audio-player', AudioPlayer)
}
// helper for music player
applyNewSrc = async (this_, attr, newValue) => {
    if (attr == 'src' && this_.audio) {
        console.log(newValue)
        this_.audio.src = newValue
        if (this_.attributes.playing && this_.attributes.playing.value == "true") {
            this_.audio.play()
        }
    }
}

module.exports = {register}
