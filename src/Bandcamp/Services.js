const fs = require('fs')
const Downloader = require("./Downloader")

function register () {
    // an iframe that opens the auth screen and steals the cookie
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

    // an iframe that opens a download page and steals a download url
    class BandcampDownload extends HTMLElement {
        constructor() {
            super()
        }
        connectedCallback() {
            var alreadyRetrieved = false
            if (!this.src || !this.id) {
                throw (new Error('id and src attributes must be set'))
            }

            const iframe = document.createElement('iframe')
            iframe.src = this.src
            // event callback
            const emitUrl = url => {
                    if (alreadyRetrieved) {return}
                    alreadyRetrieved = true
                    const retrieved = new CustomEvent('asseturlretrieve', {detail: {url}})
                    this.dispatchEvent(retrieved)
                }
            const emitComplete = url => {
                    const retrieved = new CustomEvent('downloadcomplete')
                    this.dispatchEvent(retrieved)
                }

            const targetPath = Downloader.complete_file_path(this.id)
            // create iframe
            const alreadyCompleted = fs.existsSync(targetPath)
            if (alreadyCompleted) {
                return emitComplete()
            }
            // test
            this.appendChild(iframe)
            // silence bandcamp bc it is noisy
            const grabStatDownloadLink =
                async (_, msg) => {
                    if (msg) {
                        const isAboutStatDownload =
                            msg.indexOf("statdownload") > -1
                        const isAboutDownload =
                            msg.indexOf("download") > -1
                        const isSuccess =
                            msg.indexOf("success") > -1
                        if (isAboutStatDownload && isSuccess) {
                            const blobStart = msg.indexOf('{')
                            const blob = msg.slice(blobStart -1)
                            const statUrl = JSON.parse(blob).url
                            const scriptWithDownloadUrl = await (await fetch("https://" + statUrl)).text()
                            const url = scriptWithDownloadUrl.split('"').find(part => part.indexOf("bits") > -1)
                            emitUrl(url)
                        }
                    }
                }
            iframe.contentWindow.console.log = grabStatDownloadLink
        }
    }

    customElements.define('bandcamp-auth', BandcampAuth)
    customElements.define('bandcamp-download', BandcampDownload)
}

module.exports = {register}
