// security settings for integrating with third parties

// allow iframes to be rendered within electron
const allowAppAsFrameAncestor = session => {
    // only bandcamp for now :)
    const filter = {urls: ['https://bandcamp.com/login']}
    session.webRequest.onHeadersReceived(filter, (info, callback) => {
        const responseHeaders = info.responseHeaders
        // update header
        responseHeaders['Content-Security-Policy'] ="frame-ancestors self app://-"
        // next
        callback({responseHeaders})
    });

}
const setup = app =>
    // allow stealing cookies and other stuff from iframes
    app.commandLine.appendSwitch('disable-site-isolation-trials')

module.exports = {setup, allowAppAsFrameAncestor}
