function register () {
    console.warn('registering')

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
                    console.log(iframe)
                    const cookie = iframe.contentDocument.cookie
                    console.log(cookie)
                    const retrieved = new CustomEvent('cookieretrieve', {detail: {cookie}})
                    this.dispatchEvent(retrieved)
                }
            // test
            this.addEventListener('cookieretrieve', (ev) => console.error(ev.detail))
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
        console.log(attr, newValue)
        console.log(this.audio)
        if (attr == 'name') {
          this.textContent = `Hello, ${newValue}`;
        }
        if (attr == 'src' && this.audio) {
            console.log('new tune', this.attributes.playing == "true")
            this.audio.src = newValue
            if (this.attributes.playing.value == "true") {
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
