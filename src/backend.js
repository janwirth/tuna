
const process = require('process')

const FileSystem = require('./FileSystem')
const fs = require('fs')
const path = require('path')

const DEV_LIBRARY_FILE = path.join('../library.json')
const USER_LIBRARY_FILE = path.join(FileSystem.tunaDir, 'library.json')

const isDev = require('electron-is-dev');

if (isDev) {
	console.log('Running in development');
} else {
	console.log('Running in production');
}

const LIBRARY_FILE = isDev ? DEV_LIBRARY_FILE : USER_LIBRARY_FILE

// methods
const restore = () => {
    if (fs.existsSync(LIBRARY_FILE)) {
        const data = fs.readFileSync(LIBRARY_FILE).toString()
        return JSON.parse(data)
    } else {
        return null
    }
}


const persist_ = async model => {
  const encoded = JSON.stringify(model);
  // at this point, `body` has the entire request body stored in it as a string
  fs.writeFile(LIBRARY_FILE, encoded, (err, res) => err ? console.warn(err) : console.info('saved'))
}


// Returns a function, that, as long as it continues to be invoked, will not
// be triggered. The function will be called after it stops being called for
// N milliseconds. If `immediate` is passed, trigger the function on the
// leading edge, instead of the trailing.
function debounce(func, wait, immediate) {
	var timeout;
	return function() {
		var context = this, args = arguments;
		var later = function() {
			timeout = null;
			if (!immediate) func.apply(context, args);
		};
		var callNow = immediate && !timeout;
		clearTimeout(timeout);
		timeout = setTimeout(later, wait);
		if (callNow) func.apply(context, args);
	};
};

const persist = debounce(persist_, 1000)

module.exports = {persist, restore}
