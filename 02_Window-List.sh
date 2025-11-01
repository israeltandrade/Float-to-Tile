#!/usr/bin/env bash

# File: 02_Window-List.sh
# Description: Captures the list of active, managed windows (excluding utilities) 
# and extracts their geometry, class, and workspace data using wmctrl.
# Dependencies: wmctrl, awk.

# --- Configuration & Files ---
LOG_FILE="./02_Window-List.log"
DATA_FILE="./02_Window-List.data"
LAST_VALID_STATE_FILE="./02_Window-List.last_valid_state"
TEMP_FILE="/tmp/wmctrl_list_$$"

# --- Utility Functions ---
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- Initialization & Cleanup ---
: > "$LOG_FILE"
trap 'rm -f "$TEMP_FILE"' EXIT
log "Module 02 START"

# --- Phase 1: Data Acquisition ---
log "Acquiring detailed window list via wmctrl -lxG."

if ! wmctrl -lxG > "$TEMP_FILE"; then
    log "FAILURE: Command 'wmctrl -lxG' failed. wmctrl may not be installed or the X server is unavailable."
    printf "❌ M02 FAILED: wmctrl is required but failed to execute.\n"
    exit 1
fi

# --- Phase 2: AWK Filtering and Formatting ---
log "Filtering windows and formatting output..."

# AWK script to parse wmctrl -lxG output and format KEY=VALUE pairs.
# wmctrl -lxG columns are: WID | Desktop | Pos X | Pos Y | Width | Height | Class.Resource | Hostname | Title
AWK_OUTPUT=$(awk '
    BEGIN { 
        window_count = 0; 
    }
    
    # FILTERING CRITERIA:
    # 1. Exclude known desktop utilities (xfce4-panel, xfdesktop).
    # 2. Exclude windows on desktop -1 (Sticky/Desktop/Special).
    ! /xfce4-panel|xfdesktop/ && $2 != "-1" { 
        
        # Increments counter only for windows we plan to process
        window_count++;

        # Separates Class and Resource Name (Column 7)
        split($7, class_res, ".");

        # Reconstruct the Title: Starts from column 9 to the end of the line
        window_title = "";
        for (i = 9; i <= NF; i++) {
            window_title = (window_title ? window_title " " : "") $i;
        }

        # Imprime a string KEY=VALUE (AWK Safe Print)
        print "WINDOW_" window_count "_WID=" $1;
        print "WINDOW_" window_count "_DESKTOP=" $2;
        print "WINDOW_" window_count "_CLASS=" class_res[1];      # e.g., "code"
        print "WINDOW_" window_count "_RESOURCE=" class_res[2];   # e.g., "Code"
        print "WINDOW_" window_count "_POS_X=" $3;
        print "WINDOW_" window_count "_POS_Y=" $4;
        print "WINDOW_" window_count "_WIDTH=" $5;
        print "WINDOW_" window_count "_HEIGHT=" $6;
        print "WINDOW_" window_count "_TITLE=" window_title;
    }
    
    END { 
        print "---CALCULATED---";
        print "WINDOW_COUNT=" window_count;
    }
' "$TEMP_FILE")

# --- Phase 3: Data Extraction and Validation ---
log "Extracting and validating window data components."

# Extract final values using simple AWK extraction
CALCULATED_DATA=$(echo "$AWK_OUTPUT" | awk '/---CALCULATED---/{flag=1; next} flag')
WINDOW_COUNT=$(echo "$CALCULATED_DATA" | awk -F'=' '/WINDOW_COUNT/ {print $2}')

# Validation: Check if no standard windows were found (Valid Success State)
if [ -z "$WINDOW_COUNT" ] || [ "$WINDOW_COUNT" -eq 0 ]; then
    log "SUCCESS (Empty): No standard windows found to manage. WINDOW_COUNT=0."
    WINDOW_COUNT=0 # Ensure it's explicitly zero
    
    # Must create the data file for later modules, even if empty.
    printf "WINDOW_COUNT=0\n" > "$DATA_FILE"
    cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
    
    printf "✅ M02 SUCCESS: No windows found to manage.\n"
    log "Module 02 END (SUCCESS - No Windows)"
    exit 0
fi

# --- Phase 4: Output Generation and State Persistence (If windows were found) ---
log "Generating final output and persisting state."

# Separate Window Data from Calculated Data (for clean writing)
WINDOW_DATA=$(echo "$AWK_OUTPUT" | sed -n '1,/---CALCULATED---/ { /---CALCULATED---/d; p }')

# Overwrite the current data file
{
    echo "WINDOW_COUNT=$WINDOW_COUNT"
    echo "$WINDOW_DATA"
} > "$DATA_FILE"
log "Current data successfully written to $DATA_FILE."

# Update the last valid state
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."

# --- Terminal Feedback ---
printf "✅ M02 SUCCESS: Captured %s active window(s).\n" "$WINDOW_COUNT"

log "Module 02 END (SUCCESS)"
exit 0