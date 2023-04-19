#!/usr/bin/env zsh

# Input: Transmission passes in vars for torrent info:
# TR_APP_VERSION - Transmission's short version string, e.g. 4.0.0
# TR_TIME_LOCALTIME
# TR_TORRENT_BYTES_DOWNLOADED - Number of bytes that were downloaded for this torrent
# TR_TORRENT_DIR - Location of the downloaded data
# TR_TORRENT_HASH - The torrent's info hash
# TR_TORRENT_ID – The torrent's ID in the download list
# TR_TORRENT_LABELS - A comma-delimited list of the torrent's labels
# TR_TORRENT_NAME - Name of torrent (not filename)
# TR_TORRENT_TRACKERS - A comma-delimited list of the torrent's trackers' announce URLs

# Helpers: Load from external file
source "$(dirname $0:A)/process-helpers.sh"

# Config: Check and store all the things we'll need
[[ ! -d $ZDOTDIR ]] && CONFIG_ERRORS+=("Dotfiles")
[[ ! -d $NASDIR ]] && nas-keepalive > /dev/null
[[ -d $NASDIR ]] && PLEX_PATH="$NASDIR/Plex" || CONFIG_ERRORS+=("NAS path")
[[ -d $DROPBOXDIR ]] && PROCESSING_PATH="$DROPBOXDIR/Downloads" || CONFIG_ERRORS+=("Dropbox path")
LOG_FILE="$PROCESSING_PATH/Logs/$(date '+%Y%m%d@%H%M')-$TR_TORRENT_NAME.txt"

# Config: Make sure we set things up properly and log/notify/fail if not
if [[ -n $CONFIG_ERRORS ]]; then
  LOG_FILE="$HOME/Desktop/transmission-error.txt"
  LOG_TEXT="Script error: missing config (${(j:, :)CONFIG_ERRORS})"
  print_log "$LOG_TEXT"
  send_notification "$LOG_TEXT"
  exit 1
fi

print_log "Starting postprocess for $TR_TORRENT_NAME..."

# Setup: Handle torrent info
DOWNLOAD_PATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"
LABEL=$(generate_label "$TR_TORRENT_NAME")

print_log "Processing download: $DOWNLOAD_PATH; label: $LABEL; destination: $PLEX_PATH; size: $(convert_size $TR_TORRENT_BYTES_DOWNLOADED)"

# Filebot: Call AMC script to do the thing
FILEBOT=$(/usr/local/bin/filebot -script fn:amc \
  --output "$PLEX_PATH" \
  --action duplicate -non-strict \
  --conflict auto \
  --log-file amc.log \
  --def unsorted=n music=n artwork=y \
    movieDB=TheMovieDB seriesDB=TheMovieDB::TV \
    ut_dir="$DOWNLOAD_PATH" ut_kind="multi" ut_title="$TR_TORRENT_NAME" ut_label="$LABEL" \
    exec=": {quote n}" \
    excludeList="$PROCESSING_PATH/.excludes" \
  )
print_log "$FILEBOT"

# Output: Handle whether FileBot did the thing or not and log results
[[ $FILEBOT ]] && PROCESSED=$(parse_processed $FILEBOT)
if [[ $PROCESSED && $PROCESSED -ge 1 ]]; then
  TITLE=$(parse_title "$FILEBOT")
  NOTIFICATION="$TITLE ready to Plex! 🤖🎉"
else
  NOTIFICATION="$TR_TORRENT_NAME downloaded but not processed 🤖🤷‍♀️"
  cp -r "$DOWNLOAD_PATH" "$PLEX_PATH/Unsorted" && NOTIFICATION+=" (copied to $PLEX_PATH/Unsorted)"
fi

# Notify: Trigger Shortcuts to send a notification and log
print_log "Sending Shortcuts notification: $NOTIFICATION"
send_notification "$NOTIFICATION"

# Cleanup: Move .torrent file so Transmission doesn't pick it up again and log
for FILE in "$PROCESSING_PATH/Media"/*; do
  FILE_HASH="$(transmission-show "$FILE" | awk '/Hash:/{print $2}')"
  if [[ $FILE_HASH = "$TR_TORRENT_HASH" ]]; then
    print_log "Moving $(basename "$FILE") out of watched folder"
    mv "$FILE" "$PROCESSING_PATH/Complete"
  fi
done

## Logging: done!
print_log "🤖🤖🤖🤖 Completed postprocess!"
