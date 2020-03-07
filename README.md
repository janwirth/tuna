# Music Library
A tool for people who like their own music files.

## Installation
For now you have to clone and build it yourself

## Running
```sh
npm i && npm start
```

## Design
For people who like to own their music:
A lightweight iTunes alternative that syncs your devices and integrates with bandcamp.

## User Stories
- [x] In order to listen to music I want to have a player with play / pause button
- [x] In order to play some music I want to drop it from my file browser into the library.
- [x] In order to get an overview I want to list my music
- [x] In order to easily add a lot of music I want to drop entire directories in my library
- [ ] In order to get play more music I want to connect to bandcamp
- [ ] In order to play music for a longer time I want the next track to play after the current one ends
- [ ] In order to skip tracks I want next/prev buttons
- [ ] In order to find tracks by genre or mood I want to add tags to my music
- [ ] In order to get a better overview of my music I want to have a table that supports sorting
    - [ ] date added
    - [ ] artist, title, number, album
    - [ ] parser
- [ ] In order to listen to my music while I am not on my computer I want to sync it with my mobile device
- [ ] In order to sync my devices / connect to my next workflow steps I want to drag and drop files out of the library
- [ ] In order to not lose my music I want to back it up
    - s3 glacier?
- [ ] In order to keep queues that I enjoyed listening to I want to create a playlist from a past queue

- [ ] In order to get comfortable with the app quickly I want simple text-based onboarding when absolutely necessary
- [ ] In order to prep for sets I want to create playlists
- [ ] In order to record track orders I like I want
    - ordered playlists or
    - 'working well together' tool
    - or both?

## Architecture
- bandcamp login lives inside in iframe because it requires a captcha
- client/server between elm and http server (considering iso-elm)
- Port functions were not available using `BrowserWindow.webContents`
