# Transmission post-processing script

Transmission is _the_ canonical BitTorrent app for MacOS, and can watch a single folder.

Plex is _the_ canonical media library manager, and requires separate folders for Movies and TV shows.

Makes total sense that we have to hack together a way for Transmission and Plex to play together, right?

(RIP Deluge and Auto-Add plugin)

## The magic workflow 🪄
This all came about because I want to be able to throw something on my Plex server from my couch, from work, or from anywhere. Missed the end of the movie when the in-flight entertainment shut off on landing? No prob, kick off the download and finish watching at home.

**Here's how it works:**

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
  - If downloading and Plex are both running on the same machine, this is probably just a local folder
  - If you're running Plex on a NAS, mount the drive as a network volume and find the Plex folders
- Notification shortcut (`process-helpers.sh:16`, see below): The name of a shortcut (Apple Shortcuts) to trigger
  - Notifications between Apple devices is surprisingly hard – Apple assumes that if a notification is coming from yourself, that means you've already read it, so it doesn't actually notify
  - One way to hack around this is using Reminders, here's an [example](https://www.icloud.com/shortcuts/08048084872041e8b2a9804c679f339b)

Everything else is either generated in relation to these things, is passed from Transmission, or returned from FileBot.

PSA: Transmission runs this script as a non-interactive, non-login shell. Depending on your environment, shell, and dotfile configuration, you may or may not have access to things like Homebrew paths or global variables.

~~I found that sourcing my `.zshenv` file at the top of the script is the simplest way to get the config I need (and also solves the Homebrew problem). I export environment variables for frequently used paths and tools in my dotfiles, so this way I can use `$DROPBOXDIR`, `$NASDIR`, etc.~~

**Edit:** The script's shebang also determines what it has access to. A `sh` script will run with `zsh` but isn't a real `zsh` environment. Changing to an explicit `zsh` shebang fixes this (although it causes other problems).

## Testing

I highly recommend finding some very small torrents since you will probably be downloading them over and over and over again when testing this out.

Tip: There is an anime TV show called UFO Baby that is available free on the Internet Archive, hits the right naming conventions for testing, and runs about 80–150MB per episode. I have downloaded the same two episodes dozens of times and have still not watched it.

Repeat 3,587,279 times:
1. Tweak script
1. Move `.torrent` file into watch dir
1. Wait for Transmission to transfer
1. Check the logs
1. Figure out what isn't working
1. Remove transfer and trash files in Transmission
1. Move `.torrent` file out of watch dir
1. Go to step 1

For testing things that depend more on how FileBot matches than what comes in from Transmission, I added a `test-filebot.sh` script that includes the bare bones you need to call FileBot from the command line. It's more transparent and a lot quicker than triggering Transmission over and over again.

## Helpers

I've pulled a few functions into a separate file (`process-helpers.sh`) for reusability and consistency. These are sourced in both the main script (`transmission-postprocess.sh:15`) and test script (`test-filebot.sh:9`) so there's parity between testing and the real thing.

## Edge cases & troubleshooting

The script handles most recent, well-named media you might download. There are a few bugs I've come across and fixed and I expect there will be more.

### Destination path:
- Not surprisingly, if the destination path isn't available, FileBot is gonna have a hard time. The script includes some error handling to hopefully make this transparent.
- If you're downloading and Plexing from the same machine this likely won't be an issue, but if you are copying files to a NAS then it needs to be mounted when the script runs.
- I've included a check for the NAS path (`:19`) and if it isn't a directory, call a script that remounts the NAS drive – you can grab that script from my [wifi-keepalive](https://github.com/madysondesigns/wifi-keepalive) repo.

### Torrent naming conventions:
- FileBot relies on the name embedded in the torrent metadata (not the `.torrent` filename itself) and uses that to match media. If a torrent is poorly named I assume the results will be less than spectacular, but most torrents I've come across follow good naming conventions so it's not an issue.
- Older and more obscure media can be more difficult to match – it seems to be more of an issue with TV shows, and I've found that forcing TV mode with the `tv` label helps (and I assume it can only be good for performance to narrow down the search).
- I've included some regex logic (`process-helpers.sh:31-:47`) to match common TV naming conventions (e.g. S01E01), and use the `tv` label if so (or use the label provided by Transmission, even though this isn't supported yet).
- One thing I don't think can be handled automatically is a full series pack – typically these only include the word 'complete' or nothing besides the show name so we have to rely on FileBot completely here.

### Multi-file torrents:
- If a torrent includes multiple files, FileBot will try to to match and process them as a group and individually. This affects how the `exec` command is called, depending on the [format expressions](https://www.filebot.net/naming.html) you use (currently set to `{n}`).
- Some formats (e.g. `{fn}` or episode numbers) correspond to an individual file and some (e.g. `{n}` for movie/series name) correspond to the series or movie. The script will call `exec` on each file when you include the former, and only once per match object when including the latter. A TV season pack is only one match object, but a movie pack will likely have multiple match objects, and multiple `exec` calls.
- There is a helper (`process-helpers.sh:74`) that parses the `exec` output to grab a nicely formatted name for the notification, but it's not super bulletproof. It's limited to the first matching string to prevent logging/notification errors, but for a pack it might be less accurate.

### Additional files:
- Some torrents include extras, trailers, subtitles, `.nfo` files, etc. FileBot mostly handles these automatically, and you can customize how they're handled by passing additional `--def` options.
- Sometimes FileBot processes extra files in multiple passes so there might be more than one 'Processed' string (no idea why this happens). There's a helper (`process-helpers.sh:67`) that should find all these counts and add them up to determine success but this is also a little brittle.

### Excluded or existing files:
- FileBot strongly recommends you specify an `excludesList` so it doesn't process things twice. If you're in the testing phase, and FileBot isn't matching when you re-download, check whether your files are on that list and remove them or disable it temporarily.
- FileBot also won't process if the files already exist in the destination folders. There is a `--conflict override` option available, but it hasn't worked for me. If you need to re-download something, delete the existing files before the script runs otherwise FileBot will skip them.

### Logging:
- Normal `stdout/stderr` output is sent into a black hole I haven't discovered yet, so the only way to see what's going on is to log all the things. I included a `print_log` helper to make that simpler, but it does take some trial and error to even know what to log.
- Since Transmission kicks off the script, there's no way to redirect output when calling it, but I did come across a snippet to redirect output to a file (e.g. errors or plain `print` calls) from within a script. This even applies to the logging firehose when you add `-x` to the shebang – it's super useful when iterating through more drastic changes:

  ```shell
  # Include this up front to push stdout/stderr messages to a file you define:
  exec > >(tee -a "$HOME/.tmp/transmission-post.log") 2>&1
  ```

### Shell environment config:
- I lean heavily on my dotfiles and store things I frequently use in environment variables and helper functions. `zsh` makes it super simple to configure and load those things, but that means the script leverages some `zsh` specific things and isn't portable to other shells as-is.
- Since this runs in a non-interactive, non-login shell, it only loads `.zshenv` and not `.zprofile`, `.zshrc`, or any other config files. If you've set up something in `.zshrc`, the script doesn't have access to it.
- These kinds of errors tend to blow up hard and invisibly, so the script will check for the variables it needs to run everything, and any errors will print to a file hardcoded to the `~/Desktop` path (and notify!).
- Of course, if you hardcode all the paths you need or only rely on something more universal like `$HOME`, you'll probably be fine.

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
