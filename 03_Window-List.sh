#!/usr/bin/env bash

# File: 03_Window-List.sh (v5.2 - AWK Formatting Fix, robust)
# Description: Captures window data, determines the monitor, and sorts deterministically.
# Dependencies: wmctrl, awk, sort. Depends on 01_Screen-Resolution.data and 02_Desktop-Details.data.

set -euo pipefail
IFS=$'\n\t'

# --- Configuration & Files ---
LOG_FILE="./03_Window-List.log"
DATA_FILE="./03_Window-List.data"
LAST_VALID_STATE_FILE="./03_Window-List.last_valid_state"
TEMP_WMCTRL_FILE="/tmp/wmctrl_list_$$"
TEMP_UNSORTED_FILE="/tmp/wmctrl_list_unsorted_$$"
TEMP_UNSORTED_FINAL="${TEMP_UNSORTED_FILE}.final"
MONITOR_DATA_FILE="./01_Screen-Resolution.data"
DESKTOP_DATA_FILE="./02_Desktop-Details.data"
TEMP_FINAL_DATA="/tmp/final_data_$$"

# --- Utility Functions ---
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- Monitor/Desktop Data Loading ---

# Load monitor geometry and names from 01_Screen-Resolution.data
read_monitor_data() {
    MONITOR_COUNT=$(grep '^MONITOR_COUNT=' "$MONITOR_DATA_FILE" | cut -d'=' -f2)

    m_idx=1
    while [ "$m_idx" -le "$MONITOR_COUNT" ]; do
        MONITOR_X[$m_idx]=$(grep "MONITOR_${m_idx}_POS_X" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_Y[$m_idx]=$(grep "MONITOR_${m_idx}_POS_Y" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_W[$m_idx]=$(grep "MONITOR_${m_idx}_WIDTH" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_H[$m_idx]=$(grep "MONITOR_${m_idx}_HEIGHT" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_NAME[$m_idx]=$(grep "MONITOR_${m_idx}_NAME" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        m_idx=$((m_idx + 1))
    done
}

# Load desktop names from 02_Desktop-Details.data
read_desktop_names() {
    DESKTOP_COUNT=$(grep '^DESKTOP_COUNT=' "$DESKTOP_DATA_FILE" | cut -d'=' -f2)

    d_idx=0
    while [ "$d_idx" -lt "$DESKTOP_COUNT" ]; do
        DESKTOP_NAME[$d_idx]=$(grep "DESKTOP_${d_idx}_NAME=" "$DESKTOP_DATA_FILE" | cut -d'=' -f2)
        d_idx=$((d_idx + 1))
    done
}

# Function to determine monitor based on window center point
get_monitor_id() {
    local win_x=$1 win_y=$2 win_w=$3 win_h=$4
    local center_x=$((win_x + win_w / 2))
    local center_y=$((win_y + win_h / 2))
    local monitor_id=0
    local m_idx=1

    while [ "$m_idx" -le "$MONITOR_COUNT" ]; do
        local m_x=${MONITOR_X[$m_idx]} m_y=${MONITOR_Y[$m_idx]}
        local m_w=${MONITOR_W[$m_idx]} m_h=${MONITOR_H[$m_idx]}
        
        if [ "$center_x" -ge "$m_x" ] && [ "$center_x" -lt "$((m_x + m_w))" ] && \
           [ "$center_y" -ge "$m_y" ] && [ "$center_y" -lt "$((m_y + m_h))" ]; then
            monitor_id=$m_idx
            break
        fi
        m_idx=$((m_idx + 1))
    done
    
    echo "$monitor_id"
}

# --- Initialization & Cleanup ---
: > "$LOG_FILE"
trap 'rm -f "$TEMP_WMCTRL_FILE" "$TEMP_UNSORTED_FILE" "$TEMP_UNSORTED_FINAL" "$TEMP_FINAL_DATA"' EXIT
log "Module 03 START (v5.2 - AWK Formatting Fix, robust)"

# --- Phase 1: Dependency Check & Data Load ---
if [ ! -f "$MONITOR_DATA_FILE" ]; then
    log "FAILURE: Monitor data file $MONITOR_DATA_FILE not found. Cannot proceed."
    printf "❌ M03 FAILED: Monitor data file not found.\n"
    exit 1
fi
read_monitor_data

if [ ! -f "$DESKTOP_DATA_FILE" ]; then
    log "FAILURE: Desktop data file $DESKTOP_DATA_FILE not found. Cannot proceed."
    printf "❌ M03 FAILED: Desktop data file not found.\n"
    exit 1
fi
read_desktop_names

if [ -z "${MONITOR_COUNT:-}" ] || [ "$MONITOR_COUNT" -eq 0 ]; then
    log "FAILURE: Monitor count is zero or missing in data file."
    printf "❌ M03 FAILED: Monitor count is zero or missing.\n"
    exit 1
fi

# --- Phase 2: Window Data Acquisition (wmctrl) ---
if ! wmctrl -lxG > "$TEMP_WMCTRL_FILE"; then
    log "FAILURE: Command 'wmctrl -lxG' failed."
    printf "❌ M03 FAILED: wmctrl command failed. Please ensure wmctrl is installed.\n"
    exit 1
fi

# --- Phase 3: AWK Filtering and Base Extraction ---
log "AWK: Filtering windows and extracting base data."

# Use a here-doc (quoted) to avoid any shell expansion/CRLF/citation problems
awk -f - "$TEMP_WMCTRL_FILE" > "$TEMP_UNSORTED_FILE" <<'AWK'
! /xfce4-panel|xfdesktop/ && $2 != "-1" {
    split($7, class_res, ".")
    window_title = ""
    for (i = 9; i <= NF; i++) {
        if (window_title) window_title = window_title " " $i
        else window_title = $i
    }
    # internal fields separated by '|'
    print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" class_res[1] "|" class_res[2] "|" window_title
}
AWK

# --- Phase 4: Monitor Detection (BASH) and Final Formatting/Sorting ---
log "BASH: Detecting monitor for each window and sorting."

WINDOW_COUNT=0

# Ensure the final unsorted file is created/empty before appending
: > "$TEMP_UNSORTED_FINAL"

# Loop through the AWK output
while IFS='|' read -r WID DESKTOP POS_X POS_Y WIDTH HEIGHT CLASS RESOURCE TITLE; do
    
    MONITOR_ID=$(get_monitor_id "$POS_X" "$POS_Y" "$WIDTH" "$HEIGHT")
    
    if [ "$MONITOR_ID" -eq 0 ]; then
        log "WARNING: Window $WID center point not found on any monitor. Skipping."
        continue
    fi
    
    WINDOW_COUNT=$((WINDOW_COUNT + 1))
    
    FULL_WINDOW_BLOCK=$(
        printf "WINDOW_%s_DESKTOP=%s^WINDOW_%s_MONITOR=%s^WINDOW_%s_WID=%s^WINDOW_%s_CLASS=%s^WINDOW_%s_RESOURCE=%s^WINDOW_%s_POS_X=%s^WINDOW_%s_POS_Y=%s^WINDOW_%s_WIDTH=%s^WINDOW_%s_HEIGHT=%s^WINDOW_%s_TITLE=%s" \
        "$WINDOW_COUNT" "$DESKTOP" \
        "$WINDOW_COUNT" "$MONITOR_ID" \
        "$WINDOW_COUNT" "$WID" \
        "$WINDOW_COUNT" "$CLASS" \
        "$WINDOW_COUNT" "$RESOURCE" \
        "$WINDOW_COUNT" "$POS_X" \
        "$WINDOW_COUNT" "$POS_Y" \
        "$WINDOW_COUNT" "$WIDTH" \
        "$WINDOW_COUNT" "$HEIGHT" \
        "$WINDOW_COUNT" "$TITLE"
    )
    
    # Print sort keys (pipe separated) + data block (caret separated)
    printf "%s|%s|%s|%s\n" "$DESKTOP" "$MONITOR_ID" "$WID" "$FULL_WINDOW_BLOCK" >> "$TEMP_UNSORTED_FINAL"

done < "$TEMP_UNSORTED_FILE"

# 4.3 Final Deterministic Sort: Sort by Desktop, then Monitor, then WID
SORTED_DATA=$(sort -t '|' -k1,1n -k2,2n -k3,3 "$TEMP_UNSORTED_FINAL")

# --- Phase 5: Final Formatting and Validation ---
if [ "$WINDOW_COUNT" -eq 0 ]; then
    log "SUCCESS (Empty): No standard windows found to manage. WINDOW_COUNT=0."
    printf "WINDOW_COUNT=0\n" > "$DATA_FILE"
    cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
    printf "✅ M03 SUCCESS: Captured 0 active window(s).\n"
    log "Module 03 END (SUCCESS - No Windows)"
    exit 0
fi

# Re-index the final data after sorting and store the clean, final lines
FINAL_WINDOW_count_REINDEXED=0
FINAL_WINDOW_COUNT_REINDEXED=0

# Ensure TEMP_FINAL_DATA is empty
: > "$TEMP_FINAL_DATA"

while IFS='|' read -r SORT_DESKTOP SORT_MONITOR SORT_WID FULL_WINDOW_BLOCK; do
    FINAL_WINDOW_COUNT_REINDEXED=$((FINAL_WINDOW_COUNT_REINDEXED + 1))
    
    # 1. Replace the old index with the new index
    REINDEXED_LINE=$(echo "$FULL_WINDOW_BLOCK" | sed "s/WINDOW_[0-9]*_/WINDOW_${FINAL_WINDOW_COUNT_REINDEXED}_/g")
    
    # 2. Replace the internal caret (^) separator with a clean newline (\n) and append to TEMP_FINAL_DATA
    echo "$REINDEXED_LINE" | tr '^' '\n' >> "$TEMP_FINAL_DATA"
    
done <<< "$SORTED_DATA"

# --- Phase 6: Output Generation and State Persistence (Hierarchy Headers & Buffering) ---
log "Generating final output with full hierarchy headers and persisting state."

# Overwrite the current data file
printf "WINDOW_COUNT=%s\n" "$FINAL_WINDOW_COUNT_REINDEXED" > "$DATA_FILE"

CURRENT_DESKTOP=""
CURRENT_MONITOR=""
WINDOW_BLOCK_BUFFER=""

# Loop through the final, clean data to inject headers
while IFS= read -r line; do

    # 1. Trigger: DESKTOP field (Start of a new window block)
    if [[ "$line" == WINDOW_?*_DESKTOP=* ]]; then
        # Reset buffer for new window block
        WINDOW_BLOCK_BUFFER=""

        NEW_DESKTOP=${line##*=}

        # Check for Desktop Change (Highest level header)
        if [ "$NEW_DESKTOP" != "$CURRENT_DESKTOP" ]; then

            # Extract Name and Visual Index for enhanced header
            DESKTOP_NAME_STR=${DESKTOP_NAME[$NEW_DESKTOP]:-""} # Ex: 1: 
            # Extract the visual index (e.g., '1' from '1: ') — guard empty
            VISUAL_INDEX=""
            if [ -n "$DESKTOP_NAME_STR" ]; then
                VISUAL_INDEX=$(echo "$DESKTOP_NAME_STR" | cut -d':' -f1 | tr -d ' ')
            fi

            # Print the Enhanced Desktop header
            printf "\n# ================= DESKTOP %s (Visual Index: %s | NAME: %s) =================\n" "$NEW_DESKTOP" "$VISUAL_INDEX" "$DESKTOP_NAME_STR" >> "$DATA_FILE"

            CURRENT_DESKTOP="$NEW_DESKTOP"
            CURRENT_MONITOR="" # Reset monitor context when desktop changes
        fi

        # Buffer the DESKTOP line (append a real newline)
        WINDOW_BLOCK_BUFFER+="$line"$'\n'

    # 2. Trigger: MONITOR field
    elif [[ "$line" == WINDOW_?*_MONITOR=* ]]; then
        NEW_MONITOR=${line##*=}

        # Check for Monitor Change (Mid level header)
        if [ "$NEW_MONITOR" != "$CURRENT_MONITOR" ]; then
            MONITOR_NAME_STR=${MONITOR_NAME[$NEW_MONITOR]:-""}

            # Print the Monitor header with name
            printf "\n# ------------- Monitor %s (%s) -------------\n" "$NEW_MONITOR" "$MONITOR_NAME_STR" >> "$DATA_FILE"
            CURRENT_MONITOR="$NEW_MONITOR"
        fi

        # Buffer the MONITOR line (append a real newline)
        WINDOW_BLOCK_BUFFER+="$line"$'\n'

    # 3. Trigger: WID field (This is the critical third line)
    elif [[ "$line" == WINDOW_?*_WID=* ]]; then
        # Get the WINDOW_N index
        WINDOW_INDEX=$(echo "$line" | cut -d'_' -f2)

        # Print the Window header (Lowest level header)
        printf "\n# --- Window %s ---\n" "$WINDOW_INDEX" >> "$DATA_FILE"

        # Print the buffered DESKTOP and MONITOR lines (they contain real newlines)
        printf "%s" "$WINDOW_BLOCK_BUFFER" >> "$DATA_FILE"
        WINDOW_BLOCK_BUFFER="" # Clear buffer

        # Print the WID line (which we are currently reading)
        printf "%s\n" "$line" >> "$DATA_FILE"

    # 4. Normal data field (not DESKTOP, MONITOR, or WID)
    else
        # Print remaining lines immediately
        printf "%s\n" "$line" >> "$DATA_FILE"
    fi

done < "$TEMP_FINAL_DATA"

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."

# --- Terminal Feedback ---
printf "✅ M03 SUCCESS: Captured %s active window(s) with Desktop/Monitor/Window hierarchy.\n" "$FINAL_WINDOW_COUNT_REINDEXED"
log "Module 03 END (SUCCESS)"
exit 0