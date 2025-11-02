#!/usr/bin/env bash

# File: 01_Screen-Resolution.sh
# Description: Captures the geometry of the active X11 monitors and calculates the total viewport size.

# --- PATH CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

LOG_FILE="$ROOT_DIR/Logs/01_Screen-Resolution.log"
DATA_FILE="$ROOT_DIR/Data/01_Screen-Resolution.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/01_Screen-Resolution.last_valid_state"
TEMP_FILE="/tmp/xrandr_monitors_$$"

# --- UTILITY FUNCTIONS ---

log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- INITIALIZATION ---

: > "$LOG_FILE"
trap 'rm -f "$TEMP_FILE"' EXIT
log "MODULE 01 START"

# --- DATA ACQUISITION ---

log "ACQUIRING MONITOR LIST"

if ! xrandr --listactivemonitors > "$TEMP_FILE" 2>/dev/null; then
    : > "$TEMP_FILE"
fi

log "PROCESSING GEOMETRY AND CALCULATING VIEWPORT"

monitor_count=0
max_width=0
max_height=0
MONITOR_DATA=""
DEBUG_LINES=""

geom_re='([0-9]+)(/[^x+]*)?x([0-9]+)(/[^+ ]*)?\+([0-9]+)\+([0-9]+)'

# --- PARSING LOGIC ---
_parse_file() {
    local file="$1"
    while IFS= read -r line; do
        DEBUG_LINES+=$'LINE: '"$line"$'\n'
        if [[ $line =~ $geom_re ]]; then
            ((monitor_count++))

            monitor_width="${BASH_REMATCH[1]}"
            monitor_height="${BASH_REMATCH[3]}"
            monitor_pos_x="${BASH_REMATCH[5]}"
            monitor_pos_y="${BASH_REMATCH[6]}"

            monitor_name="$(awk '{print $NF}' <<< "$line")"

            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_NAME='"$monitor_name"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_WIDTH='"$monitor_width"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_HEIGHT='"$monitor_height"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_POS_X='"$monitor_pos_x"$'\n'
            MONITOR_DATA+=$'MONITOR_'"$monitor_count"'_POS_Y='"$monitor_pos_y"$'\n'

            w=$((monitor_pos_x + monitor_width))
            h=$((monitor_pos_y + monitor_height))
            (( w > max_width )) && max_width=$w
            (( h > max_height )) && max_height=$h
        fi
    done < "$file"
}

# --- EXECUTION FLOW ---
_parse_file "$TEMP_FILE"

if [ "$monitor_count" -eq 0 ]; then
    log "FALLBACK: NO MONITORS PARSED, TRYING XRANDR --QUERY"
    xrandr --query > "${TEMP_FILE}.full" 2>/dev/null || : > "${TEMP_FILE}.full"
    _parse_file "${TEMP_FILE}.full"
    DEBUG_LINES+="--- FALLBACK (xrandr --query) ---"$'\n'
    DEBUG_LINES+=$(sed -n '1,200p' "${TEMP_FILE}.full")
fi

AWK_OUTPUT="${MONITOR_DATA}---CALCULATED---"$'\n'"MONITOR_COUNT=${monitor_count}"$'\n'"VIEWPORT_WIDTH=${max_width}"$'\n'"VIEWPORT_HEIGHT=${max_height}"

log "EXTRACTING AND VALIDATING DATA"

MONITOR_DATA=$(printf "%s\n" "$AWK_OUTPUT" | sed -n '1,/---CALCULATED---/ { /---CALCULATED---/d; p }')
CALCULATED_DATA=$(printf "%s\n" "$AWK_OUTPUT" | awk '/---CALCULATED---/{flag=1; next} flag')

VIEWPORT_WIDTH=$(printf "%s\n" "$CALCULATED_DATA" | awk -F'=' '/VIEWPORT_WIDTH/ {print $2}')
VIEWPORT_HEIGHT=$(printf "%s\n" "$CALCULATED_DATA" | awk -F'=' '/VIEWPORT_HEIGHT/ {print $2}')
MONITOR_COUNT=$(printf "%s\n" "$CALCULATED_DATA" | awk -F'=' '/MONITOR_COUNT/ {print $2}')

# --- FAILURE CHECK ---
if [ -z "$VIEWPORT_WIDTH" ] || [ -z "$VIEWPORT_HEIGHT" ] || [ -z "$MONITOR_COUNT" ] || [ "$MONITOR_COUNT" -eq 0 ]; then
    log "FAILURE: ESSENTIAL GEOMETRY DATA IS MISSING."
    log "DEBUG: AWK_OUTPUT CONTENT:"
    while IFS= read -r l; do log "DEBUG: $l"; done <<< "$AWK_OUTPUT"

    log "DEBUG: RAW LINES SCANNED:"
    while IFS= read -r l; do log "DEBUG: $l"; done <<< "$DEBUG_LINES"

    printf "❌ M01 FAILED: Could not extract geometry data. Check log for DEBUG.\n"
    log "MODULE 01 END (FAILURE)"
    exit 1
fi

# --- FINAL OUTPUT AND STATE PERSISTENCE ---

log "GENERATING FINAL OUTPUT AND PERSISTING STATE"

{
    echo "VIEWPORT_WIDTH=$VIEWPORT_WIDTH"
    echo "VIEWPORT_HEIGHT=$VIEWPORT_HEIGHT"
    echo "MONITOR_COUNT=$MONITOR_COUNT"
    echo "$MONITOR_DATA"
} > "$DATA_FILE"
log "DATA SUCCESSFULLY WRITTEN TO $DATA_FILE."

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "DATA STATE SUCCESSFULLY BACKED UP TO $LAST_VALID_STATE_FILE."

printf "✅ M01 SUCCESS: Data captured: %s monitor(s), Viewport %s x %s.\n" "$MONITOR_COUNT" "$VIEWPORT_WIDTH" "$VIEWPORT_HEIGHT"

log "MODULE 01 END (SUCCESS)"
exit 0