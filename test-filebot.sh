#!/usr/bin/env zsh

# This script is a simplified version of the main postprocess script that can
# test FileBot matching directly from the command line. Intended to be run on
# previously downloaded files to tweak FileBot options & formats.
# Usage: `./test-filebot.sh "path/to/downloaded.torrent"`

# get torrent passed in as an arg and slice off name
DOWNLOAD_PATH="$1"
TR_TORRENT_NAME=$(basename "$DOWNLOAD_PATH")

# boilerplate stuff that's auto-generated in the real script
PLEX_PATH="$( cd "$( dirname "$BASH_SOURCE[0]" )" > /dev/null && pwd )/test"
LABEL="tv"

# finding things in scrollback sucks
print "🟢🟢🟢🟢🟢 START TEST for $TR_TORRENT_NAME 🟢🟢🟢🟢🟢"

# do the thing, using symlink action because it's faster
FILEBOT=$(/usr/local/bin/filebot -script fn:amc \
  --output "$PLEX_PATH" \
  --action symlink -non-strict \
  --conflict auto \
  --log-file amc.log \
  --def unsorted=n music=n artwork=y \
    movieDB=TheMovieDB seriesDB=TheMovieDB::TV \
    ut_dir="$DOWNLOAD_PATH" ut_kind="multi" ut_title="$TR_TORRENT_NAME" ut_label="$LABEL" \
    exec="printf {quote primaryTitle} > /dev/null" \
  )
print "$FILEBOT"

# find the "Processed # files" string and parse the number
[[ $FILEBOT ]] && PROCESSED=$(awk '/^Processed/{print $2}' <<< "$FILEBOT")
print "Processed files: $PROCESSED"

if [[ $PROCESSED -ge 1 ]]; then
  # if any files were processed, find the "Execute: ..." string and parse the title
  TITLE=$(awk -F"\' | \'" '/^Execute/{print $2; exit}' <<< "$FILEBOT")
  print "$TITLE processed successfully! 🤖🎉"
else
  print "$TR_TORRENT_NAME not processed 🤖🤷‍♀️"
fi
