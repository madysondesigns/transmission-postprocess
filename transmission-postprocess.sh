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

# Config: Get environment vars and store working directories & helpers
[[ -d $DROPBOXDIR ]] && PROCESSING_PATH="$DROPBOXDIR/Downloads"
[[ -d $NASDIR ]] && PLEX_PATH="$NASDIR/Plex"
DOWNLOAD_PATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"
LOG_FILE="$PROCESSING_PATH/Logs/$(date '+%Y%m%d@%H%M')-$TR_TORRENT_NAME.txt"
NOTIFY_SHORTCUT="Notify All Devices"

# Logging: Helper to make it less repetitve
print_log () {
  print "[$(date "+%F %T")] $1" >> "$LOG_FILE"
}

# Logging: Helper to make downloaded size easier to grok
convert_size () {
  local -F gigabytes=$(print -f "%.2f" "$(($1))e-9")
  local -F megabytes=$(print -f "%.2f" "$(($1))e-6")
  local LC_ALL=en_US.UTF-8

  if [[ $gigabytes -ge 1 ]]; then
    print -f "%'gGB" "$gigabytes"
  elif [[ $megabytes -ge 1 ]]; then
    print -f "%'.0fMB" "$megabytes"
  else
    print -f "%'gb" "$1"
  fi
}

# Config: Make sure we set things up properly and log/notify/fail if not
if [[ ! $PROCESSING_PATH || ! $PLEX_PATH ]]; then
  LOG_FILE="$HOME/Desktop/transmission-error.txt"
  print_log "Transmission script error: Unable to set config from env variables (\$ZDOTDIR: $ZDOTDIR; \$DROPBOXDIR: $DROPBOXDIR; \$NASDIR: $NASDIR)"
  print -n "Transmission script error, check error log" | shortcuts run "$NOTIFY_SHORTCUT"
  exit 1
fi

# Logging: Start a logfile for date and torrent
print_log "Starting postprocess for $TR_TORRENT_NAME..."

# Setup: Check if file matches common TV naming patterns
probably_tv () {
  local name=$1

  declare -A newpats
  newpats["matches 'S00' pattern"]="[S|s][0-9]{1,4}"
  newpats["includes 'season' string"]="Season|season"
  newpats["matches 'E00' pattern"]="[E|e]p?[0-9]{1,2}"
  newpats["matches '0x00' pattern"]="[0-9]{1,2}x[0-9]{1,2}"
  newpats["includes 'series' string"]="Series|series"
  newpats["includes 'episode' string"]="Episode|episode"

  for description pattern in ${(kv)newpats}; do
    [[ "$name" =~ "$pattern" ]] && print "${(Q)description}" && return
  done

  return 1
}
TV_MATCH=$(probably_tv "$TR_TORRENT_NAME")

# Setup: Handle labels if we have them and log results
if [[ $TR_TORRENT_LABELS ]]; then
  print_log "Using for $TR_TORRENT_NAME passed from Transmission"
  LABEL=$TR_TORRENT_LABELS
elif [[ $TV_MATCH ]]; then
  print_log "$TR_TORRENT_NAME $TV_MATCH, adding TV label"
  LABEL="tv"
else
  print_log "No labels for $TR_TORRENT_NAME, allowing FileBot to detect"
  LABEL="N/A"
fi

# Logging: Print the params and info we've generated so far
print_log "Processing $TR_TORRENT_NAME with label: $LABEL; source: $DOWNLOAD_PATH; destination: $PLEX_PATH; size: $(convert_size $TR_TORRENT_BYTES_DOWNLOADED)"

# Filebot: Call AMC script to do the thing
FILEBOT=$(/usr/local/bin/filebot -script fn:amc \
  --output "$PLEX_PATH" \
  --action duplicate -non-strict \
  --conflict auto \
  --log-file amc.log \
  --def unsorted=n music=n artwork=y \
    movieDB=TheMovieDB seriesDB=TheMovieDB::TV \
    ut_dir="$DOWNLOAD_PATH" ut_kind="multi" ut_title="$TR_TORRENT_NAME" ut_label="$LABEL" \
    exec="printf {quote primaryTitle} > /dev/null" \
    excludeList="$PROCESSING_PATH/.excludes" \
  )

# Output: Handle whether FileBot did the thing or not and log results
print_log "$FILEBOT"
[[ $FILEBOT ]] && PROCESSED=$(awk '/^Processed/{print $2}' <<< "$FILEBOT")
if [[ $PROCESSED -ge 1 ]]; then
  TITLE=$(awk -F"\' | \'" '/^Execute/{print $2; exit}' <<< "$FILEBOT")
  NOTIFICATION="$TITLE ready to Plex! 🤖🎉"
else
  NOTIFICATION="$TR_TORRENT_NAME downloaded but not processed 🤖🤷‍♀️"
  cp -r "$DOWNLOAD_PATH" "$PLEX_PATH/Unsorted" && NOTIFICATION+=" (copied to $PLEX_PATH/Unsorted)"
fi

# Notify: Trigger Shortcuts to send a notification and log
print_log "Sending Shortcuts notification: $NOTIFICATION"
print -n "$NOTIFICATION" | shortcuts run "$NOTIFY_SHORTCUT"

# Cleanup: Move .torrent file so Transmission doesn't pick it up again and log
for FILE in "$PROCESSING_PATH/Media"/*
do
  FILE_HASH="$(transmission-show "$FILE" | awk '/Hash:/{print $2}')"
  if [[ $FILE_HASH = "$TR_TORRENT_HASH" ]]; then
    print_log "Moving $(basename "$FILE") out of watched folder"
    mv "$FILE" "$PROCESSING_PATH/Complete"
  fi
done

## Logging: done!
print_log "🤖🤖🤖🤖 Completed postprocess!"
