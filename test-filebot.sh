#!/usr/bin/env zsh

# This script is a simplified version of the main postprocess script that can
# test FileBot matching directly from the command line. Intended to be run on
# previously downloaded files to tweak FileBot options & formats.
# Usage: `./test-filebot.sh "path/to/downloaded.torrent"`

SCRIPT_PATH=$(dirname $0:A)
source "$SCRIPT_PATH/process-helpers.sh"

# get torrent passed in as an arg and slice off name
DOWNLOAD_PATH="$1"
TR_TORRENT_NAME=$(basename "$DOWNLOAD_PATH")

# boilerplate stuff that's auto-generated in the real script
OUTPUT_PATH="$SCRIPT_PATH/test"
LOG_FILE="$OUTPUT_PATH/$TR_TORRENT_NAME.txt"

# finding things in scrollback sucks
print_log "🟢🟢🟢 Testing $TR_TORRENT_NAME 🟢🟢🟢"

# set label
LABEL=$(generate_label "$TR_TORRENT_NAME")

# do the thing, using symlink action because it's faster
FILEBOT=$(/usr/local/bin/filebot -script fn:amc \
  --output "$OUTPUT_PATH" \
  --action symlink -non-strict \
  --conflict override \
  --log-file amc.log \
  --def unsorted=n music=n artwork=n \
    movieDB=TheMovieDB seriesDB=TheMovieDB::TV \
    ut_dir="$DOWNLOAD_PATH" ut_kind="multi" ut_title="$TR_TORRENT_NAME" ut_label="$LABEL" \
    exec=": {quote n}" \
  )
print_log "$FILEBOT"

# check how many files were processed
[[ $FILEBOT ]] && PROCESSED=$(parse_processed $FILEBOT)
print_log "Processed $PROCESSED files"

# log results
if [[ $PROCESSED && $PROCESSED -ge 1 ]]; then
  TITLE=$(parse_title "$FILEBOT")
  print_log "🤖🤖🤖 $TITLE processed successfully! 🎉 🤖🤖🤖"
else
  print_log "🤖🤖🤖 $TR_TORRENT_NAME not processed 🤷‍♀️ 🤖🤖🤖"
fi
