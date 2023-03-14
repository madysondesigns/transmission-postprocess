# Transmission post-processing script

Transmission is _the_ canonical BitTorrent app for MacOS, and can watch a single folder.

Plex is _the_ canonical media library manager, and requires separate folders for Movies and TV shows.

Makes total sense that we have to hack together a way for Transmission and Plex to play together, right?

(RIP Deluge and Auto-Add plugin)

## The magic workflow 🪄
This all came about because I want to be able to throw something on my Plex server from my couch, from work, or from anywhere. Missed the end of the movie when the in-flight entertainment shut off on landing? No prob, kick off the download and finish watching at home.

Here's how it works:

### 🙋‍♀️ Step 1: Grab your `.torrent` file 👈 _this is the only step where you have to do something_
- Find the media you want to download from the public domain, open source, Creative Commons, or other **legal** torrent site of your choice
  - Did you know the Internet Archive has a huge [video library](https://archive.org/details/movies) with tons of free movies and TV shows available as torrents?
- Download the `.torrent` file and save it to a specific folder in Dropbox
  - You can do this from any device or platform that can save to Dropbox, including mobile

### 🔄 Step 2: Dropbox triggers Transmission
- Dropbox syncs your new file to the download machine in a folder Transmission is watching
- Transmission sees the file and starts a transfer to download the media itself

### 📥 Step 3: Transmission passes to FileBot AMC
- When the transfer completes, Transmission calls the post-process script
- The script collects the moving parts, tries to help FileBot handle TV vs. movies, and logs all the things
  - FileBot needs labels for reliable matching, but Transmission doesn't pass anything like this to the script so we do some regex magic to help FileBot if it looks like a TV show

### 🤖 Step 4: FileBot copies to Plex folders
- FileBot tries to match the media in the movie and/or TV database specified
- Once it finds a match, it copies the media to the corresponding Plex library with proper Plex folder/naming conventions
  - You can also configure FileBot to grab movie or series artwork and copy that over so Plex has something pretty to display

### 🔔 Step 5: Notify & cleanup
- Parse Filebot's output to see whether it processed the file for Plex
  - If FileBot wasn't able to process it, copy it to an Unsorted folder to handle manually
- Send a notification via Shortcuts that the media is ready! (or that it wasn't processed)
- Move the original `.torrent` file out of the Dropbox downloads folder
  - If Transmission restarts for any reason, it will try to add what's in the watched folder and get cranky if it's already in the transfers list

### 🎬 Step 6: Movie time!
- Load up Plex and start watching!

## Setting it up

### Moving parts that make this work
- Cloud sync platform of your choice (I use Dropbox #notsponsored)
  - Create a folder to save `.torrent` files to download
  - Create a folder for completed `.torrent`s
  - Create a folder for logs
- Machine that downloads the things (my Mac Mini)
  - Install [Transmission](http://transmissionbt.com/) and [FileBot](http://filebot.net/)
  - Set Transmission's watched folder to the downloads folder in Dropbox
  - Tell Transmission to run this script when it finishes a download
- Machine that runs Plex Media Server (NAS server in my case)
  - Mount a NAS drive as a network volume

Transmission and Plex Media Server can both run on almost anything. Either or both can run on most desktop computers, both can run on many modern NAS servers, and both can even run from a Raspberry Pi. You'll need some extra drives for that one, though.

_Before I upgraded to the Mac Mini, I was running this on an iMac from **2009** that worked perfectly fine until Dropbox stopped supporting El Capitan..._

### Customizing the script
- `$PROCESSING_PATH`: the Dropbox folder where the script & related stuff live. The script currently expects these folders:
  - `[Dropbox folder]/Downloads` (script lives in the root)
    - `[Dropbox folder]/Downloads/Media` (folder for new `.torrent` files that Transmission watches)
    - `[Dropbox folder]/Downloads/Complete` (script moves `.torrent` files here once transfer is complete)
    - `[Dropbox folder]/Downloads/Logs` (script creates a timestamped file for each download)
- `$PLEX_PATH`: The folder that contains Plex's Movie and TV Shows library folders
  - If downloading and Plex are both running on the same machine, this is probably just a local folder.
  - If you're running Plex on a NAS, mount the drive as a network volume and find the Plex folders
- `$NOTIFY_SHORTCUT`: The name of a shortcut (Apple Shortcuts) to trigger
  - Notifications between Apple devices is surprisingly hard – Apple assumes that if a notification is coming from yourself, that means you've already read it, so it doesn't actually notify.
  - One way to hack around this is using Reminders, here's an [example](https://www.icloud.com/shortcuts/989e685a87d74349864cfcc9c93846c5)

Everything else is either generated in relation to these things, is passed from Transmission, or returned from FileBot.

PSA: Transmission runs this script as a non-interactive, non-login shell. Depending on your environment, shell, and dotfile configuration, you may or may not have access to things like Homebrew paths or global variables.

I found that sourcing my `.zshenv` file at the top of the script is the simplest way to get the config I need (and also solves the Homebrew problem). I export environment variables for frequently used paths and tools in my dotfiles, so this way I can use `$DROPBOXDIR`, `$NASDIR`, etc.

## Testing

I highly recommend finding some very small torrents since you will probably be downloading them over and over and over again when testing this out.

Repeat 3,587,279 times:
1. Tweak script
2. Move `.torrent` file into watch dir
3. Wait for Transmission to transfer
4. Check the logs
5. Figure out what isn't working
6. Remove transfer and trash files in Transmission
7. Move `.torrent` file out of watch dir
8. Go to step 1

## More info

### FileBot
- [AMC script info](https://www.filebot.net/forums/viewtopic.php?t=215)
- [Transmission setup instructions](https://www.filebot.net/forums/viewtopic.php?p=3380#p3380)

### Transmission
- [Scripting info & examples](https://github.com/transmission/transmission/blob/main/docs/Scripts.md)

### Plex
- [Naming and organizing Movies](https://support.plex.tv/articles/naming-and-organizing-your-movie-media-files/)
- [Naming and organizing TV shows](https://support.plex.tv/articles/naming-and-organizing-your-tv-show-files/)

## Legal stuff
Released under GPL 3.0. Feel free to use, tweak, and remix this as you like. If you come up with something cool, let me know!

This script just handles the files & apps involved. It's your responsibility to acquire media legally.
