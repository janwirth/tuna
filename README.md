# Tuna
A cross-platform app for music collectors who appreciate working with files.

## Installation
For now you will have to clone and build it yourself.

## Running
```sh
npm i && npm start
```

## Concept
Tuna's goal is to provide a well-rounded experience around collecting music.
It is for those who appreciate access to files and artwork while saving time.
In a nutshell, it is (/I am planning to make it) a lightweight iTunes alternative that syncs your devices and integrates with bandcamp.
Easily add, organize and never lose your music files.

## User Stories
Given a music-collecting power-user that appreciates simplicity.
- [x] In order to listen to music I want to have a player with play / pause button
- [x] In order to play some music I want to drop it from my file browser into the library.
- [x] In order to get an overview I want to list my music
- [x] In order to easily add a lot of music I want to drop entire directories in my library
- [ ] In order to get play more music I want to connect to bandcamp
- [ ] In order to play music for a longer time I want the next track to play after the current one ends
    - playing a track creates a queue according to the current view (sorting / filtering etc.)
- [ ] In order to skip tracks I want next/prev buttons
- [ ] In order to find tracks by genre or mood I want to add tags to my music
    - examples: genre:house:lo-fi genre:dnb:neurofunk mood:chill set:house-party
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
- [ ] In order to prepare set lists including non-digital music, I want to track vinyl (ang CD?) releases.

## Design inspiration
- waves: https://codepen.io/Qurel/pen/ZEGXomr
    - could this be used as a visualizer
- vinyl player: https://dribbble.com/shots/5930806-AR-music-library
    - maybe a minimial player mode
    - reminds me of my work with C. Molka at Mercedes-Benz.io.

## Architecture
- elm app inside electron with preferably tiny native slave modules
- bandcamp login lives inside in iframe because it requires a captcha
    - formerly: http-client-server becasue I did not know about `nodeIntegration: true`
