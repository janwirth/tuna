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

