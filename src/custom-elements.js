function register () {

    class BandcampAuth extends HTMLElement {
        constructor() {
            super()
        }
        connectedCallback() {
            // create iframe
            const iframe = document.createElement('iframe')
            iframe.src = "https://bandcamp.com/login"
            // event callback
            const extractCookie = ev => {
                    const cookie = iframe.contentDocument.cookie
                    const retrieved = new CustomEvent('cookieretrieve', {detail: {cookie}})
                    this.dispatchEvent(retrieved)
                }
            // test
            iframe.addEventListener('load', extractCookie, false)
            this.appendChild(iframe)
            // silence bandcamp bc it is noisy
            iframe.contentWindow.console.log = () => undefined
        }
    }

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
                this.audio.src = this.src
            }
            if (this.playing) {
                this.audio.play()
            }
        }

  // Monitor the 'name' attribute for changes.
  static get observedAttributes() {return ['name', 'src', 'playing']; }

  // Respond to attribute changes.
  attributeChangedCallback(attr, oldValue, newValue) {
        if (attr == 'name') {
          this.textContent = `Hello, ${newValue}`;
        }
        if (attr == 'src' && this.audio) {
            this.audio.src = newValue
            if (this.attributes.playing && this.attributes.playing.value == "true") {
                this.audio.play()
            }
        }
        if (attr === 'playing' && newValue === "true" && this.audio) {
            if (newValue) {
                this.audio.play()
            } else {
                this.audio.pause()
            }
        }
      }
    }

    customElements.define('bandcamp-auth', BandcampAuth)
    customElements.define('audio-player', AudioPlayer)
}

module.exports = {register}
