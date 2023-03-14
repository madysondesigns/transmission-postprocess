#!/usr/bin/env sh -xu

# Transmission passes in vars for torrent info:
# TR_APP_VERSION - Transmission's short version string, e.g. 4.0.0
# TR_TIME_LOCALTIME
# TR_TORRENT_BYTES_DOWNLOADED - Number of bytes that were downloaded for this torrent
# TR_TORRENT_DIR - Location of the downloaded data
# TR_TORRENT_HASH - The torrent's info hash
# TR_TORRENT_ID – The torrent's ID in the download list
# TR_TORRENT_LABELS - A comma-delimited list of the torrent's labels
# TR_TORRENT_NAME - Name of torrent (not filename)
# TR_TORRENT_TRACKERS - A comma-delimited list of the torrent's trackers' announce URLs

# Get custom env stuff so we have vars and homebrew – non-interactive shells don't get it automatically 🤷‍♀️
source $HOME/.zshenv

# Configuration
# Get working directories from environment vars
PROCESSING_PATH="$DROPBOXDIR/Downloads"
PLEX_PATH="$NASDIR/Plex"
# Set up other config we'll need later
LOG_DATE="+%F %T"
DOWNLOAD_PATH="$TR_TORRENT_DIR/$TR_TORRENT_NAME"
LOG_FILE="$PROCESSING_PATH/Logs/$(date '+%Y%m%d@%H%M')-$TR_TORRENT_NAME.txt"
NOTIFY_SHORTCUT="Notify All Devices"

# Create log for date and file
echo "[$(date "$LOG_DATE")] Starting postprocess for $TR_TORRENT_NAME..." > $LOG_FILE

# Check if file matches common TV naming patterns
probably_tv () {
  local name=$1

  local pattern1="[S|s]\d{1,4}" # S0, S00, S0000 (case insensitive)
  local pattern2="Season|season" # Season or season
  local pattern3="[E|e]p?\d{1,2}" # E0, Ep0, E00, Ep00 (case insensitive)
  local pattern4="\d{1,2}x\d{1,2}" # 0x00, 00x00
  local pattern5="Series|series" # Series or series
  local pattern6="Episode|episode" # Episode or episode

  local patterns=($pattern1 $pattern2 $pattern3 $pattern4 $pattern5 $pattern6)
  local description=("matches 'S00' pattern" "includes 'season' text" "matches 'E00' pattern" "matches '0x00' pattern" "includes 'series' text" "includes 'episode' text")

  for pattern in ${!patterns[@]}; do
    if (echo $name | grep -Eq  ${patterns[$pattern]}); then
      echo "${description[$pattern]}"
      return 0
    fi
  done

  return 1
}
TV_MATCH=$(probably_tv "$TR_TORRENT_NAME")

# Handle labels if we have them
if [[ $TR_TORRENT_LABELS ]]; then
  echo "[$(date "$LOG_DATE")] Using for $TR_TORRENT_NAME passed from Transmission" >> $LOG_FILE
  LABEL=$TR_TORRENT_LABELS
elif [[ $TV_MATCH ]]; then
  echo "[$(date "$LOG_DATE")] $TR_TORRENT_NAME $TV_MATCH, adding TV label" >> $LOG_FILE
  LABEL="tv"
else
  echo "[$(date "$LOG_DATE")] No labels for $TR_TORRENT_NAME, allowing FileBot to detect" >> $LOG_FILE
  LABEL="N/A"
fi

echo "[$(date "$LOG_DATE")] Processing $TR_TORRENT_NAME with label: $LABEL; source: $DOWNLOAD_PATH; destination: $PLEX_PATH; size: $TR_TORRENT_BYTES_DOWNLOADED" >> $LOG_FILE

# Call FileBot to do the thing
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

echo "\n$FILEBOT\n" >> $LOG_FILE

# Handle whether FileBot did the thing or not
[[ $FILEBOT ]] && MATCHED=$(echo -e "$FILEBOT" | awk -F" " '/^Processed/{print $2}')
if [[ $MATCHED -ge 1 ]]; then
  MEDIA=$(echo -e "$FILEBOT" | awk -F"\' | \'" '/^Execute/{print $2}')
  NOTIFICATION="$MEDIA ready to Plex! 🤖🎉"
else
  NOTIFICATION="$TR_TORRENT_NAME downloaded but not processed 🤖🤷‍♀️"
  cp -r "$DOWNLOAD_PATH" "$PLEX_PATH/Unsorted" && NOTIFICATION+=" (copied to $PLEX_PATH/Unsorted)"
fi

# Trigger Shortcuts to send a notification
echo "[$(date "$LOG_DATE")] Sending Shortcuts notification: $NOTIFICATION" >> $LOG_FILE
printf "$NOTIFICATION" | shortcuts run "$NOTIFY_SHORTCUT"

# Move .torrent file so Transmission doesn't pick it up again
for FILE in "$PROCESSING_PATH/Media"/*
do
  FILE_HASH="$(transmission-show "$FILE" | awk '/Hash:/{print $2}')"
  if [[ $FILE_HASH = $TR_TORRENT_HASH ]]; then
    echo "[$(date "$LOG_DATE")] Moving $(basename "$FILE") out of watched folder" >> $LOG_FILE
    mv "$FILE" "$PROCESSING_PATH/Complete"
  fi
done

echo "[$(date "$LOG_DATE")] 🤖🤖🤖🤖 Completed postprocess!" >> $LOG_FILE
