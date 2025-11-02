#!/usr/bin/env bash

# File: 02_Desktop-Details.sh
# Description: Captures detailed information about all available virtual desktops.
# Dependencies: wmctrl, awk.

# --- PATH CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

LOG_FILE="$ROOT_DIR/Logs/02_Desktop-Details.log"
DATA_FILE="$ROOT_DIR/Data/02_Desktop-Details.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/02_Desktop-Details.last_valid_state"
TEMP_WMCTRL_FILE="/tmp/wmctrl_desktop_$$"
TEMP_FINAL_DATA="/tmp/desktop_data_$$"

# --- UTILITY FUNCTIONS ---
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- INITIALIZATION ---
: > "$LOG_FILE"
trap 'rm -f "$TEMP_WMCTRL_FILE" "$TEMP_FINAL_DATA"' EXIT
log "MODULE 02 START"

# --- DATA ACQUISITION ---
log "EXECUTING WMCTRL -D"

if ! wmctrl -d > "$TEMP_WMCTRL_FILE"; then
    log "FAILURE: WMCTRL -D command failed."
    printf "❌ M02 FAILED: wmctrl command failed. Please ensure wmctrl is installed.\n"
    exit 1
fi

# --- AWK PARSING AND EXTRACTION ---
log "PARSING WMCTRL OUTPUT"

awk '
{
    desktop_index = $1; 
    is_active = ($2 == "*"); 

    wa_coords_field = $8;
    wa_wh_str = $9;
    
    split(wa_coords_field, wa_coords, ","); 
    work_area_x = wa_coords[1];
    work_area_y = wa_coords[2];
    
    split(wa_wh_str, wa_dim, "x");
    work_area_width = wa_dim[1];
    work_area_height = wa_dim[2];
    
    visual_name = "";
    for (i = 10; i <= NF; i++) {
        visual_name = visual_name (i > 10 ? " " : "") $i;
    }

    printf "\n# --- DESKTOP %s ---\n", desktop_index;

    printf "DESKTOP_%s_ACTIVE=%s\n", desktop_index, (is_active ? "true" : "false");
    printf "DESKTOP_%s_NAME=%s\n", desktop_index, visual_name;
    printf "DESKTOP_%s_WORK_AREA_X=%s\n", desktop_index, work_area_x;
    printf "DESKTOP_%s_WORK_AREA_Y=%s\n", desktop_index, work_area_y;
    printf "DESKTOP_%s_WORK_AREA_WIDTH=%s\n", desktop_index, work_area_width;
    printf "DESKTOP_%s_WORK_AREA_HEIGHT=%s\n", desktop_index, work_area_height;
}
' "$TEMP_WMCTRL_FILE" > "$TEMP_FINAL_DATA"

# --- OUTPUT GENERATION AND STATE PERSISTENCE ---

DESKTOP_COUNT=$(wc -l < "$TEMP_WMCTRL_FILE")
log "DETECTED DESKTOP_COUNT=${DESKTOP_COUNT}."

printf "DESKTOP_COUNT=%s\n" "$DESKTOP_COUNT" > "$DATA_FILE"

cat "$TEMP_FINAL_DATA" >> "$DATA_FILE"

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "DATA STATE SUCCESSFULLY BACKED UP."

printf "✅ M02 SUCCESS: Captured %s desktop details.\n" "$DESKTOP_COUNT"
log "MODULE 02 END (SUCCESS)"
exit 0