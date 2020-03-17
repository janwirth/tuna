# Tuna
For music collectors who like files.

## Features
- [x] Quick tags
- [x] Drop from filesystem
    - read media tags automatically
- [x] Bandcamp integration
    - revision-hashed files
- [ ] actions
    - [ ] select one or many tracks
    - [ ] batch-process tracks
        - quick-tag
        - delete
        - enqueue
- [ ] Queue
    - add tracks
    - move tracks around
    - save as tag

## Installation
[Download latest release](//github.com/franzskuffka/tuna/releases).
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
- [x] In order to get play more music I want to connect to bandcamp
- [x] In order to play music for a longer time I want the next track to play after the current one ends
    - [x] playing a track creates a queue according to the current view (sorting / filtering etc.)
- [x] As a user and dev I want a testing and a user mode to not pollute my actual library while polluting
- [x] In order to quickly create playlists I want a quick-add tag button
- [ ] In order to recover my taggings I want to normalize tags and include them in custom tags
    - [ ] genre:foo
    - [ ] bpm:123
    - [ ] tracknumber:
- [ ] in order to use bandcamp properly I want downloads to work reliably :angry-face:
- [ ] In order to sync my devices / connect to my next workflow steps I want to drag and drop files out of the library
- [ ] In order to quickly find specific tracks or albums I want a full-text search across all fields
- [ ] In order to view sub-collections I want to create playlists which are essentially stored searches
- [ ] In order to enrich my music library data set I want to read additional data from source files
- [ ] In order to tidy up my library I want powerful batch editing
- [ ] In order to quickly navigate through my library I want keyboard support
    - [ ] control player: next, prev, play, pause, volume
    - [ ] control browser: move up/down, select, play selected
- [ ] in order to learn about tuna without installing it I want to
    - [ ] see pictures of the app
        - idea: use desktop capturer https://ourcodeworld.com/articles/read/280/creating-screenshots-of-your-app-or-the-screen-in-electron-framework
    - [ ] Read about the app
- [ ] as maintainer in order to minimize repetetive overhead I want to release a new version of tuna in a single command
    - [ ] ensure library does not get lost
    - [ ] publish upgradeable release
    - [ ] update website
- [ ] In order to skip tracks I want next/prev buttons
- [ ] in order to recover my music and playlists I want an iTunes import
    - deferred, right now I do not have itunes on my machine
- [ ] In order to find tracks by genre or mood I want to add tags to my music
    - [ ] tag field next to track
    - [ ] CRUD filterable views
        - [ ] view
    - examples: genre:house:lo-fi genre:dnb:neurofunk mood:chill set:house-party
- [ ] in order
- [ ] in order to see when my music is ready I want a download status information
    - [x] global download progress indicator
    - [ ] download list with progress for each downloaded item
    - [ ] download error info
- [ ] In order to get a better overview of my music I want to have a table that supports sorting
    - [ ] date added
    - [ ] artist, title, number, album
    - [ ] parser
- [ ] In order to listen to my music while I am not on my computer I want to sync it with my mobile device
- [ ] In order to not lose my music I want to back it up
    - NAS?
    - backblaze?
    - s3 glacier?
- [ ] In order to keep queues that I enjoyed listening to I want to create a playlist from a past queue

- [ ] In order to get comfortable with the app quickly I want simple text-based onboarding when absolutely necessary
- [ ] In order to prep for sets I want to create playlists
- [ ] In order to record track orders I like I want
    - ordered playlists or
    - 'working well together' tool
    - or both?
- [ ] In order to prepare set lists including non-digital music, I want to track vinyl (ang CD?) releases.
- [ ] In order to have a more care-free experience I can opt into fully managed mode

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
- proposal: keep tags in dict and use bandcamp and id3 as metadata truth

## Random Notes / Prio
- fix bandcamp downloads
    - use purchase_id
    - use bandcamp as source of truth
    - keep tags separate from tracks
- fix genre tag import
- emoji picker next to track
- next/prev
- emoji selecte multiple emoji
- enable drop-out

