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

# Config: Helpers for logging & notification
LOG_DATE="+%F %T"
NOTIFY_SHORTCUT="Notify All Devices"

# Config: Get environment vars and store working directories
[[ -d $DROPBOXDIR ]] && PROCESSING_PATH="$DROPBOXDIR/Downloads"
[[ -d $NASDIR ]] && PLEX_PATH="$NASDIR/Plex"
DOWNLOAD_PATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"
LOG_FILE="$PROCESSING_PATH/Logs/$(date '+%Y%m%d@%H%M')-$TR_TORRENT_NAME.txt"

# Config: Make sure we set things up properly and log/notify if not
if [[ ! $PROCESSING_PATH || ! $PLEX_PATH ]]; then
  ERROR_LOG="$HOME/Desktop/transmission-error.txt"
  print "[$(date "$LOG_DATE")] Transmission script error: Unable to set config from env variables (\$ZDOTDIR: $ZDOTDIR; \$DROPBOXDIR: $DROPBOXDIR; \$NASDIR: $NASDIR)" >> "$ERROR_LOG"
  printf "Transmission script error, check error log" | shortcuts run "$NOTIFY_SHORTCUT"
  exit 1
fi

# Logging: Start a logfile for date and torrent
print "[$(date "$LOG_DATE")] Starting postprocess for $TR_TORRENT_NAME..." > "$LOG_FILE"

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
  print "[$(date "$LOG_DATE")] Using for $TR_TORRENT_NAME passed from Transmission" >> "$LOG_FILE"
  LABEL=$TR_TORRENT_LABELS
elif [[ $TV_MATCH ]]; then
  print "[$(date "$LOG_DATE")] $TR_TORRENT_NAME $TV_MATCH, adding TV label" >> "$LOG_FILE"
  LABEL="tv"
else
  print "[$(date "$LOG_DATE")] No labels for $TR_TORRENT_NAME, allowing FileBot to detect" >> "$LOG_FILE"
  LABEL="N/A"
fi

# Logging: Print the params and info we've generated so far
print "[$(date "$LOG_DATE")] Processing $TR_TORRENT_NAME with label: $LABEL; source: $DOWNLOAD_PATH; destination: $PLEX_PATH; size: $TR_TORRENT_BYTES_DOWNLOADED" >> "$LOG_FILE"

# Filebot: Call AMC script to do the thing
FILEBOT=$(/usr/local/bin/filebot -script fn:amc \
  --output "$PLEX_PATH" \
  --action duplicate -non-strict \
  --conflict auto \
  --log-file amc.log \
  --def unsorted=n music=n artwork=y \
    movieDB=TheMovieDB seriesDB=TheMovieDB::TV \
    ut_dir="$DOWNLOAD_PATH" ut_kind="multi" ut_title="$TR_TORRENT_NAME" ut_label="$LABEL" \
    exec="printf {quote fn} &> /dev/null" \
    excludeList="$PROCESSING_PATH/.excludes" \
  )

# Output: Handle whether FileBot did the thing or not and log results
print "\n$FILEBOT\n" >> "$LOG_FILE"
[[ $FILEBOT ]] && MATCHED=$(print -e "$FILEBOT" | awk -F" " '/^Processed/{print $2}')
if [[ $MATCHED -ge 1 ]]; then
  MEDIA=$(print -e "$FILEBOT" | awk -F"\' | \'" '/^Execute/{print $2}')
  NOTIFICATION="$MEDIA ready to Plex! 🤖🎉"
else
  NOTIFICATION="$TR_TORRENT_NAME downloaded but not processed 🤖🤷‍♀️"
  cp -r "$DOWNLOAD_PATH" "$PLEX_PATH/Unsorted" && NOTIFICATION+=" (copied to $PLEX_PATH/Unsorted)"
fi

# Notify: Trigger Shortcuts to send a notification and log
print "[$(date "$LOG_DATE")] Sending Shortcuts notification: $NOTIFICATION" >> "$LOG_FILE"
printf "$NOTIFICATION" | shortcuts run "$NOTIFY_SHORTCUT"

# Cleanup: Move .torrent file so Transmission doesn't pick it up again and log
for FILE in "$PROCESSING_PATH/Media"/*
do
  FILE_HASH="$(transmission-show "$FILE" | awk '/Hash:/{print $2}')"
  if [[ $FILE_HASH = "$TR_TORRENT_HASH" ]]; then
    print "[$(date "$LOG_DATE")] Moving $(basename "$FILE") out of watched folder" >> "$LOG_FILE"
    mv "$FILE" "$PROCESSING_PATH/Complete"
  fi
done

## Logging: done!
print "[$(date "$LOG_DATE")] 🤖🤖🤖🤖 Completed postprocess!" >> "$LOG_FILE"
