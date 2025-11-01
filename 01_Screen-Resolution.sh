#!/usr/bin/env bash

# File: 01_Screen-Resolution.sh
# Description: Captures the geometry of the active X11 monitors and calculates the total viewport size.

LOG_FILE="./01_Screen-Resolution.log"
DATA_FILE="./01_Screen-Resolution.data"
LAST_VALID_STATE_FILE="./01_Screen-Resolution.last_valid_state"
TEMP_FILE="/tmp/xrandr_monitors_$$"

log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

: > "$LOG_FILE"
trap 'rm -f "$TEMP_FILE"' EXIT
log "Module 01 START"

log "Acquiring active monitor list via xrandr."

# Try --listactivemonitors first (more compact). If it fails, still continue to try --query below.
if ! xrandr --listactivemonitors > "$TEMP_FILE" 2>/dev/null; then
    # keep file empty; fallback will run
    : > "$TEMP_FILE"
fi

# If the file is empty or parsing finds nothing later, we'll try full query as fallback.
log "Processing data and calculating viewport geometry..."

monitor_count=0
max_width=0
max_height=0
MONITOR_DATA=""
DEBUG_LINES=""

# Regex that accepts optional physical-size parts like "1920/344x1080/193+0+0"
# Groups: 1 = width, 2 = (opt), 3 = height, 4 = (opt), 5 = pos_x, 6 = pos_y
geom_re='([0-9]+)(/[^x+]*)?x([0-9]+)(/[^+ ]*)?\+([0-9]+)\+([0-9]+)'

# function to parse a given file
_parse_file() {
    local file="$1"
    while IFS= read -r line; do
        DEBUG_LINES+=$'LINE: '"$line"$'\n'
        # try to find geometry anywhere in the line
        if [[ $line =~ $geom_re ]]; then
            ((monitor_count++))

            monitor_width="${BASH_REMATCH[1]}"
            monitor_height="${BASH_REMATCH[3]}"
            monitor_pos_x="${BASH_REMATCH[5]}"
            monitor_pos_y="${BASH_REMATCH[6]}"

            # attempt to get monitor name (usually last token)
            monitor_name="$(awk '{print $NF}' <<< "$line")"

            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_NAME='"$monitor_name"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_WIDTH='"$monitor_width"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_HEIGHT='"$monitor_height"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_POS_X='"$monitor_pos_x"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_POS_Y='"$monitor_pos_y"$'\n'

            # update viewport max values
            w=$((monitor_pos_x + monitor_width))
            h=$((monitor_pos_y + monitor_height))
            (( w > max_width )) && max_width=$w
            (( h > max_height )) && max_height=$h
        fi
    done < "$file"
}

# first pass: parse --listactivemonitors output (if any)
_parse_file "$TEMP_FILE"

# fallback: if nothing found, try full xrandr query
if [ "$monitor_count" -eq 0 ]; then
    log "No monitors parsed from --listactivemonitors; trying 'xrandr --query' fallback."
    xrandr --query > "${TEMP_FILE}.full" 2>/dev/null || : > "${TEMP_FILE}.full"
    _parse_file "${TEMP_FILE}.full"
    # append the fallback contents to DEBUG_LINES as well
    DEBUG_LINES+="--- fallback (xrandr --query) ---"$'\n'
    DEBUG_LINES+=$(sed -n '1,200p' "${TEMP_FILE}.full")
fi

# assemble AWK_OUTPUT-like block so rest of script remains compatible
AWK_OUTPUT="${MONITOR_DATA}---CALCULATED---"$'\n'"MONITOR_COUNT=${monitor_count}"$'\n'"VIEWPORT_WIDTH=${max_width}"$'\n'"VIEWPORT_HEIGHT=${max_height}"

log "Extracting and validating data components."

MONITOR_DATA=$(printf "%s\n" "$AWK_OUTPUT" | sed -n '1,/---CALCULATED---/ { /---CALCULATED---/d; p }')
CALCULATED_DATA=$(printf "%s\n" "$AWK_OUTPUT" | awk '/---CALCULATED---/{flag=1; next} flag')

VIEWPORT_WIDTH=$(printf "%s\n" "$CALCULATED_DATA" | awk -F'=' '/VIEWPORT_WIDTH/ {print $2}')
VIEWPORT_HEIGHT=$(printf "%s\n" "$CALCULATED_DATA" | awk -F'=' '/VIEWPORT_HEIGHT/ {print $2}')
MONITOR_COUNT=$(printf "%s\n" "$CALCULATED_DATA" | awk -F'=' '/MONITOR_COUNT/ {print $2}')

if [ -z "$VIEWPORT_WIDTH" ] || [ -z "$VIEWPORT_HEIGHT" ] || [ -z "$MONITOR_COUNT" ] || [ "$MONITOR_COUNT" -eq 0 ]; then
    log "FAILURE: Essential geometry data is missing or monitor count is zero."
    log "DEBUG: AWK_OUTPUT content:"
    while IFS= read -r l; do log "DEBUG: $l"; done <<< "$AWK_OUTPUT"

    # also log the debug lines we collected when parsing
    log "DEBUG: Raw lines scanned:"
    while IFS= read -r l; do log "DEBUG: $l"; done <<< "$DEBUG_LINES"

    # advise user and exit
    printf "❌ M01 FAILED: Não foi possível extrair geometria. Veja o log para DEBUG.\n"
    log "Module 01 END (FAILURE)"
    exit 1
fi

log "Generating final output and persisting state."

{
    echo "VIEWPORT_WIDTH=$VIEWPORT_WIDTH"
    echo "VIEWPORT_HEIGHT=$VIEWPORT_HEIGHT"
    echo "MONITOR_COUNT=$MONITOR_COUNT"
    echo "$MONITOR_DATA"
} > "$DATA_FILE"
log "Current data successfully written to $DATA_FILE."

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."

printf "✅ M01 SUCCESS: Data captured: %s monitor(s), Viewport %s x %s.\n" "$MONITOR_COUNT" "$VIEWPORT_WIDTH" "$VIEWPORT_HEIGHT"

log "Module 01 END (SUCCESS)"
exit 0