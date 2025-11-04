#!/bin/bash
# 01_ACTION_Tile.sh: Main action module to apply the current tiling layout.
# REFACTOR: Logic for Monitor Area Calculation (4) and Floating Window Filter (5)
#           moved to dedicated modules 04_Monitor-Area.sh and 05_Floating-WIDs.sh.

# -----------------------------------------------------------------------------
# 1. INITIALIZATION & GLOBAL PATHS
# -----------------------------------------------------------------------------

# Get the directory where this script resides, then go up one level to the project root.
ROOT_DIR="$(dirname "$(dirname "$0")")"
CONFIG_FILE="$ROOT_DIR/global_config.conf"

# Define data locations
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$ROOT_DIR/Logs/01_ACTION_Tile_$(date +%Y%m%d).log"

# Log function for debugging
log() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') [01_ACTION_Tile] - $1" >> "$LOG_FILE"
}

# --- 2. LOAD CONFIGURATION ---

# Load configuration variables (e.g., TILING_MODE, GAP_SIZE_PX)
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log "INFO: Loaded configuration from $CONFIG_FILE"
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    exit 1
fi

# --- 3. LOAD ENVIRONMENT DATA ---

# Source all collected data files to make their variables available.
# NOTE: Modules 04 and 05 must be run prior to this action.
if [[ -f "$DATA_DIR/01_Screen-Resolution.data" ]] && \
   [[ -f "$DATA_DIR/02_Desktop-Details.data" ]] && \
   [[ -f "$DATA_DIR/03_Window-List.data" ]] && \
   [[ -f "$DATA_DIR/04_Monitor-Area.data" ]] && \
   [[ -f "$DATA_DIR/05_Floating-WIDs.data" ]]; then
    
    source "$DATA_DIR/01_Screen-Resolution.data"
    source "$DATA_DIR/02_Desktop-Details.data"
    source "$DATA_DIR/03_Window-List.data"
    source "$DATA_DIR/04_Monitor-Area.data" # Provides USABLE_AREA_N_* variables
    source "$DATA_DIR/05_Floating-WIDs.data" # Provides FLOAT_WID_LIST
    log "INFO: Loaded all environment data (including calculated areas and floating list)."
else
    log "ERROR: Required data files not found in $DATA_DIR. Run data collection modules (01-05) first."
    exit 1
fi

# --- 4. DATA IS NOW LOADED (Area and Floating Filter logic was externalized) ---

# All variables required for tiling (Monitor Area, Floating WIDs) are available
# from the sourced .data files. We can now jump straight to the Tiling Logic.

# --- 5. EXECUTE TILING LOGIC ---

log "INFO: Starting tiling logic for TILING_MODE: $TILING_MODE"

# 5.1. Initialization of Floating WIDs Filter
# Convert the comma-separated string of floating WIDs into an associative array for fast lookup.
declare -A IS_FLOATING
if [[ -n "$FLOAT_WID_LIST" ]]; then
    IFS=',' read -ra FLOAT_WID_ARRAY <<< "$FLOAT_WID_LIST"
    for wid in "${FLOAT_WID_ARRAY[@]}"; do
        IS_FLOATING["$wid"]=1
    done
    log "DEBUG: Initialized floating WID lookup table."
fi

# 5.2. Grouping Windows by Monitor and Desktop (Filtering out floating windows)
# Associative array to hold lists of WIDs to tile: TILE_WIDS[DesktopID_MonitorID] = "WID1 WID2 WID3"
declare -A TILE_WIDS
CURRENT_DESKTOP_ID=$(grep DESKTOP_?*_ACTIVE=true "$DATA_DIR/02_Desktop-Details.data" | head -n 1 | cut -d'_' -f2)

log "INFO: Current Desktop ID: $CURRENT_DESKTOP_ID"

if [ -z "$WINDOW_COUNT" ] || [ "$WINDOW_COUNT" -eq 0 ]; then
    log "INFO: No windows detected. Exiting tiling logic."
else
    for ((i = 1; i <= WINDOW_COUNT; i++)); do
        WID_VAR="WINDOW_${i}_WID"
        MONITOR_VAR="WINDOW_${i}_MONITOR"
        DESKTOP_VAR="WINDOW_${i}_DESKTOP"
        
        WID=${!WID_VAR}
        MONITOR_ID=${!MONITOR_VAR}
        DESKTOP_ID=${!DESKTOP_VAR}

        # Only process windows on the current desktop AND not in the floating list
        if [[ "$DESKTOP_ID" -eq "$CURRENT_DESKTOP_ID" ]] && [[ ! ${IS_FLOATING["$WID"]+x} ]]; then
            
            # The key is DesktopID_MonitorID
            KEY="${DESKTOP_ID}_${MONITOR_ID}"
            
            # Append the WID to the list for this group
            TILE_WIDS["$KEY"]="${TILE_WIDS["$KEY"]} $WID"
        else
            log "DEBUG: Skipping $WID (Desktop: $DESKTOP_ID, Floating: ${IS_FLOATING["$WID"]+x})"
        fi
    done
fi

log "INFO: Found ${#TILE_WIDS[@]} groups of tileable windows."

# 5.3. Tiling Algorithm Execution (Simple Master/Stack for now)

# Iterate over all groups identified in the previous step
for KEY in "${!TILE_WIDS[@]}"; do
    # KEY format is "DesktopID_MonitorID"
    D_ID=$(echo "$KEY" | cut -d'_' -f1)
    M_ID=$(echo "$KEY" | cut -d'_' -f2)

    # Clean the list of WIDs (remove leading/trailing spaces) and split into an array
    WID_LIST_CLEANED=$(echo "${TILE_WIDS[$KEY]}" | xargs)
    read -ra WIDS_TO_TILE <<< "$WID_LIST_CLEANED"
    
    WINDOW_GROUP_COUNT=${#WIDS_TO_TILE[@]}

    if [ "$WINDOW_GROUP_COUNT" -eq 0 ]; then
        continue # Should not happen, but safe check
    fi
    
    log "TILING: Desktop $D_ID, Monitor $M_ID has $WINDOW_GROUP_COUNT windows to tile."

    # Get the usable area for this monitor
    X_AREA_VAR="USABLE_AREA_${M_ID}_X"; X_AREA=${!X_AREA_VAR}
    Y_AREA_VAR="USABLE_AREA_${M_ID}_Y"; Y_AREA=${!Y_AREA_VAR}
    W_AREA_VAR="USABLE_AREA_${M_ID}_WIDTH"; W_AREA=${!W_AREA_VAR}
    H_AREA_VAR="USABLE_AREA_${M_ID}_HEIGHT"; H_AREA=${!H_AREA_VAR}

    # Use the first window as the MASTER (WIDS_TO_TILE[0])
    MASTER_WID="${WIDS_TO_TILE[0]}"
    
    # Calculate dimensions for the Master Window (50% of width)
    MASTER_WIDTH=$((W_AREA / 2 - GAP_SIZE_PX / 2)) # Half width minus half gap
    MASTER_HEIGHT=$((H_AREA)) # Full height
    MASTER_X=$((X_AREA)) # Starts at the left edge
    MASTER_Y=$((Y_AREA)) # Starts at the top edge

    # Send the command to the window manager (wmctrl)
    # wmctrl -i -r <WID> -e <G>,<X>,<Y>,<W>,<H>
    # G=0 means geometry relative to the screen, not the root window (important for tiling)
    wmctrl -i -r "$MASTER_WID" -e 0,"$MASTER_X","$MASTER_Y","$MASTER_WIDTH","$MASTER_HEIGHT"
    log "ACTION: Tiled Master $MASTER_WID to $MASTER_X,$MASTER_Y,${MASTER_WIDTH}x${MASTER_HEIGHT}"

    # Calculate dimensions for Stack Windows (remaining windows)
    if [ "$WINDOW_GROUP_COUNT" -gt 1 ]; then
        
        STACK_X=$((X_AREA + MASTER_WIDTH + GAP_SIZE_PX)) # Starts after master + gap
        STACK_WIDTH=$((W_AREA / 2 - GAP_SIZE_PX / 2)) # Half width minus half gap
        STACK_Y_OFFSET=0

        # Calculate height for each stack window
        STACK_WINDOWS_COUNT=$((WINDOW_GROUP_COUNT - 1))
        # Height = (Total Height - (Number of gaps * Gap Size)) / Number of windows
        STACK_HEIGHT=$(((H_AREA - (STACK_WINDOWS_COUNT - 1) * GAP_SIZE_PX) / STACK_WINDOWS_COUNT))
        
        # Iterate over stack windows (from index 1 onwards)
        for ((k = 1; k < WINDOW_GROUP_COUNT; k++)); do
            STACK_WID="${WIDS_TO_TILE[$k]}"

            # Calculate Y position: Base Y + Offset
            STACK_Y=$((Y_AREA + STACK_Y_OFFSET))
            
            # Send the command to the window manager (wmctrl)
            wmctrl -i -r "$STACK_WID" -e 0,"$STACK_X","$STACK_Y","$STACK_WIDTH","$STACK_HEIGHT"
            log "ACTION: Tiled Stack $STACK_WID to $STACK_X,$STACK_Y,${STACK_WIDTH}x${STACK_HEIGHT}"

            # Update offset for the next window
            STACK_Y_OFFSET=$((STACK_Y_OFFSET + STACK_HEIGHT + GAP_SIZE_PX))
        done
    fi

done

log "INFO: Tiling execution finished."

# --- 6. FINAL CLEANUP / STATE SAVING ---

# ... Lógica final virá aqui ...
