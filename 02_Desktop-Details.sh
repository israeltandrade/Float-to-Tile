#!/usr/bin/env bash

# File: 02_Desktop-Details.sh (v1.5)
# Description: Captures detailed information about all available virtual desktops
#              from wmctrl, including their work area and visual names/icons.
# Dependencies: wmctrl, awk.

# --- Configuration & Files ---
LOG_FILE="./02_Desktop-Details.log"
DATA_FILE="./02_Desktop-Details.data"
LAST_VALID_STATE_FILE="./02_Desktop-Details.last_valid_state"
TEMP_WMCTRL_FILE="/tmp/wmctrl_desktop_$$"
TEMP_FINAL_DATA="/tmp/desktop_data_$$"

# --- Utility Functions ---
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- Initialization & Cleanup ---
: > "$LOG_FILE"
# Ensure all temporary files are cleaned up on exit
trap 'rm -f "$TEMP_WMCTRL_FILE" "$TEMP_FINAL_DATA"' EXIT
log "Module 02 START (v1.5 - Desktop Details Capture)"

# --- Phase 1: Data Acquisition (wmctrl -d) ---
if ! wmctrl -d > "$TEMP_WMCTRL_FILE"; then
    log "FAILURE: Command 'wmctrl -d' failed. wmctrl may not be installed."
    printf "❌ M02 FAILED: wmctrl command failed. Please ensure wmctrl is installed.\n"
    exit 1
fi

# --- Phase 2: AWK Parsing and Extraction ---
log "AWK: Parsing wmctrl -d output."

# AWK logic to extract Index, Active Status, Work Area (WA), and Visual Name
awk '
{
    # Example Line: 0 * DG: 2880x2700 VP: 0,0 WA: 0,1666 2880x988 1: 
    
    # 1. Get Index and Active Status
    desktop_index = $1; 
    is_active = ($2 == "*"); 

    # 2. Get WA (Work Area) - WA: <X>,<Y> <W>x<H>
    
    # WA Coordinates are in field 8 (e.g., 0,1666)
    wa_coords_field = $8;
    
    # WA Dimensions are in field 9 (e.g., 2880x988)
    wa_wh_str = $9;
    
    # Split coordinates field ($8) by comma to get X and Y
    split(wa_coords_field, wa_coords, ","); 
    work_area_x = wa_coords[1]; # Renomeado para descritivo
    work_area_y = wa_coords[2]; # Renomeado para descritivo
    
    # Split dimensions field ($9) by 'x' to get W and H
    split(wa_wh_str, wa_dim, "x");
    work_area_width = wa_dim[1];  # Renomeado para descritivo
    work_area_height = wa_dim[2]; # Renomeado para descritivo
    
    # 3. Get Visual Name/Icon (from 10th field onwards)
    visual_name = "";
    # Join fields 10 to NF to get the visual name and icon (e.g., "1: ")
    for (i = 10; i <= NF; i++) {
        visual_name = visual_name (i > 10 ? " " : "") $i;
    }

    # Print separator and header for visual clarity
    printf "\n# --- DESKTOP %s ---\n", desktop_index;

    # Print to temporary file
    printf "DESKTOP_%s_ACTIVE=%s\n", desktop_index, (is_active ? "true" : "false");
    printf "DESKTOP_%s_NAME=%s\n", desktop_index, visual_name;
    printf "DESKTOP_%s_WORK_AREA_X=%s\n", desktop_index, work_area_x;
    printf "DESKTOP_%s_WORK_AREA_Y=%s\n", desktop_index, work_area_y;
    printf "DESKTOP_%s_WORK_AREA_WIDTH=%s\n", desktop_index, work_area_width;
    printf "DESKTOP_%s_WORK_AREA_HEIGHT=%s\n", desktop_index, work_area_height;
}
' "$TEMP_WMCTRL_FILE" > "$TEMP_FINAL_DATA"

# --- Phase 3: Output Generation and State Persistence ---
# Calculate the total number of lines (desktops) in the wmctrl output
DESKTOP_COUNT=$(wc -l < "$TEMP_WMCTRL_FILE")
log "Detected DESKTOP_COUNT=${DESKTOP_COUNT}."

# 1. Write the count to the data file
printf "DESKTOP_COUNT=%s\n" "$DESKTOP_COUNT" > "$DATA_FILE"

# 2. Append the parsed desktop data
cat "$TEMP_FINAL_DATA" >> "$DATA_FILE"

# 3. Persist the current state to the last valid state file
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."

# --- Terminal Feedback ---
printf "✅ M02 SUCCESS: Captured %s desktop details.\n" "$DESKTOP_COUNT"
log "Module 02 END (SUCCESS)"
exit 0