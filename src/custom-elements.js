function register () {
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
            this.audio.addEventListener('play', ev => this.dispatchEvent(new Event('play')))
            this.audio.addEventListener('pause', ev => this.dispatchEvent(new Event(ev.target.ended ? 'end' : 'pause')))
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
    customElements.define('audio-player', AudioPlayer)
}

module.exports = {register}
