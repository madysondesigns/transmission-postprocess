#!/usr/bin/env zsh

# Helpers for Transmission/FileBot processing

# Make logging less repetitve
print_log () {
  if [[ -z $LOG_FILE ]]; then
    print "Script error: \$LOG_FILE not defined" && exit 1
  else
    print "[$(date "+%F %T")] $1" | tee -a "$LOG_FILE"
  fi
}

# Notify via Shortcuts
send_notification () {
  print "$1" | shortcuts run "Notify All Devices"
}

# Make downloaded size easier to grok
convert_size () {
  local -F gigabytes=$(print -f "%.1f" "$(($1))e-9")
  local -F megabytes=$(print -f "%.0f" "$(($1))e-6")
  local LC_ALL=en_US.UTF-8

  [[ $gigabytes -ge 1 ]] && print -f "%'gGB" "$gigabytes" && return
  [[ $megabytes -ge 1 ]] && print -f "%'.0fMB" "$megabytes" && return
  print -f "%'gb" "$1" && return
}

# Check if file matches common TV naming patterns
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

# Handle labels if we have them
update_label () {
  local tv_match=$(probably_tv "$1")

  if [[ $TR_TORRENT_LABELS ]]; then
    LABEL="$TR_TORRENT_LABELS"
    print_log "Using labels for $1 passed from Transmission"
  elif [[ $tv_match ]]; then
    LABEL="tv"
    print_log "$1 $tv_match, using TV label"
  else
    print_log "No labels for $1, allowing FileBot to detect"
  fi
}

# Find the "Processed # files" string and parse the number
parse_processed () {
  local processed=$(sed -En "s/^Processed ([0-9]+).*$/\1/p" <<< "$1")
  local total=$(paste -sd+ - <<< $processed | bc)
  print "$total" && return
}

# If any files were processed, find the exec output and parse the title
parse_title () {
  local title=$(sed -En "s/^Execute: : '(.+)'$/\1/p" <<< "$1" | head -1)
  print "$title" && return
}
