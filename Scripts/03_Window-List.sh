#!/usr/bin/env bash

# File: 03_Window-List.sh
# Description: Captures window data, determines the monitor, and sorts deterministically.
# Dependencies: wmctrl, awk, sort. Depends on 01_Screen-Resolution.data and 02_Desktop-Details.data.

set -euo pipefail
IFS=$'\n\t'

# --- PATH CONFIGURATION ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

LOG_FILE="$ROOT_DIR/Logs/03_Window-List.log"
DATA_FILE="$ROOT_DIR/Data/03_Window-List.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/03_Window-List.last_valid_state"

MONITOR_DATA_FILE="$ROOT_DIR/Data/01_Screen-Resolution.data"
DESKTOP_DATA_FILE="$ROOT_DIR/Data/02_Desktop-Details.data"

TEMP_WMCTRL_FILE="/tmp/wmctrl_list_$$"
TEMP_UNSORTED_FILE="/tmp/wmctrl_list_unsorted_$$"
TEMP_UNSORTED_FINAL="${TEMP_UNSORTED_FILE}.final"
TEMP_FINAL_DATA="/tmp/final_data_$$"

# --- UTILITY FUNCTIONS ---
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- MONITOR/DESKTOP DATA LOADING ---

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

read_desktop_names() {
    DESKTOP_COUNT=$(grep '^DESKTOP_COUNT=' "$DESKTOP_DATA_FILE" | cut -d'=' -f2)

    d_idx=0
    while [ "$d_idx" -lt "$DESKTOP_COUNT" ]; do
        DESKTOP_NAME[$d_idx]=$(grep "DESKTOP_${d_idx}_NAME=" "$DESKTOP_DATA_FILE" | cut -d'=' -f2)
        d_idx=$((d_idx + 1))
    done
}

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

# --- INITIALIZATION ---
: > "$LOG_FILE"
trap 'rm -f "$TEMP_WMCTRL_FILE" "$TEMP_UNSORTED_FILE" "$TEMP_UNSORTED_FINAL" "$TEMP_FINAL_DATA"' EXIT
log "MODULE 03 START"

# --- DEPENDENCY CHECK & DATA LOAD ---
if [ ! -f "$MONITOR_DATA_FILE" ]; then
    log "FAILURE: Monitor data file $MONITOR_DATA_FILE not found."
    printf "❌ M03 FAILED: Monitor data file not found.\n"
    exit 1
fi
read_monitor_data

if [ ! -f "$DESKTOP_DATA_FILE" ]; then
    log "FAILURE: Desktop data file $DESKTOP_DATA_FILE not found."
    printf "❌ M03 FAILED: Desktop data file not found.\n"
    exit 1
fi
read_desktop_names

if [ -z "${MONITOR_COUNT:-}" ] || [ "$MONITOR_COUNT" -eq 0 ]; then
    log "FAILURE: Monitor count is zero or missing in data file."
    printf "❌ M03 FAILED: Monitor count is zero or missing.\n"
    exit 1
fi

# --- WINDOW DATA ACQUISITION ---
log "EXECUTING WMCTRL -LXG"
if ! wmctrl -lxG > "$TEMP_WMCTRL_FILE"; then
    log "FAILURE: Command 'wmctrl -lxG' failed."
    printf "❌ M03 FAILED: wmctrl command failed. Please ensure wmctrl is installed.\n"
    exit 1
fi

# --- AWK FILTERING AND BASE EXTRACTION ---
log "AWK: FILTERING WINDOWS"

awk -f - "$TEMP_WMCTRL_FILE" > "$TEMP_UNSORTED_FILE" <<'AWK'
! /xfce4-panel|xfdesktop/ && $2 != "-1" {
    split($7, class_res, ".")
    window_title = ""
    for (i = 9; i <= NF; i++) {
        if (window_title) window_title = window_title " " $i
        else window_title = $i
    }
    print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" class_res[1] "|" class_res[2] "|" window_title
}
AWK

# --- MONITOR DETECTION (BASH) AND FINAL FORMATTING/SORTING ---
log "BASH: DETECTING MONITOR FOR EACH WINDOW AND SORTING"

WINDOW_COUNT=0

: > "$TEMP_UNSORTED_FINAL"

while IFS='|' read -r WID DESKTOP POS_X POS_Y WIDTH HEIGHT CLASS RESOURCE TITLE; do
    
    MONITOR_ID=$(get_monitor_id "$POS_X" "$POS_Y" "$WIDTH" "$HEIGHT")
    
    if [ "$MONITOR_ID" -eq 0 ]; then
        log "WARNING: WINDOW $WID CENTER POINT NOT FOUND ON ANY MONITOR. SKIPPING."
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
    
    printf "%s|%s|%s|%s\n" "$DESKTOP" "$MONITOR_ID" "$WID" "$FULL_WINDOW_BLOCK" >> "$TEMP_UNSORTED_FINAL"

done < "$TEMP_UNSORTED_FILE"

# --- FINAL DETERMINISTIC SORT ---
SORTED_DATA=$(sort -t '|' -k1,1n -k2,2n -k3,3 "$TEMP_UNSORTED_FINAL")

# --- FINAL FORMATTING AND VALIDATION ---
if [ "$WINDOW_COUNT" -eq 0 ]; then
    log "SUCCESS (EMPTY): NO STANDARD WINDOWS FOUND TO MANAGE. WINDOW_COUNT=0."
    printf "WINDOW_COUNT=0\n" > "$DATA_FILE"
    cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
    printf "✅ M03 SUCCESS: Captured 0 active window(s).\n"
    log "MODULE 03 END (SUCCESS - No Windows)"
    exit 0
fi

# --- RE-INDEXING ---
FINAL_WINDOW_COUNT_REINDEXED=0

: > "$TEMP_FINAL_DATA"

while IFS='|' read -r SORT_DESKTOP SORT_MONITOR SORT_WID FULL_WINDOW_BLOCK; do
    FINAL_WINDOW_COUNT_REINDEXED=$((FINAL_WINDOW_COUNT_REINDEXED + 1))
    
    REINDEXED_LINE=$(echo "$FULL_WINDOW_BLOCK" | sed "s/WINDOW_[0-9]*_/WINDOW_${FINAL_WINDOW_COUNT_REINDEXED}_/g")
    
    echo "$REINDEXED_LINE" | tr '^' '\n' >> "$TEMP_FINAL_DATA"
    
done <<< "$SORTED_DATA"

# --- OUTPUT GENERATION AND STATE PERSISTENCE ---
log "GENERATING FINAL OUTPUT WITH HIERARCHY HEADERS AND PERSISTING STATE"

printf "WINDOW_COUNT=%s\n" "$FINAL_WINDOW_COUNT_REINDEXED" > "$DATA_FILE"

CURRENT_DESKTOP=""
CURRENT_MONITOR=""
WINDOW_BLOCK_BUFFER=""

while IFS= read -r line; do

    if [[ "$line" == WINDOW_?*_DESKTOP=* ]]; then
        WINDOW_BLOCK_BUFFER=""

        NEW_DESKTOP=${line##*=}

        if [ "$NEW_DESKTOP" != "$CURRENT_DESKTOP" ]; then

            DESKTOP_NAME_STR=${DESKTOP_NAME[$NEW_DESKTOP]:-""}
            VISUAL_INDEX=""
            if [ -n "$DESKTOP_NAME_STR" ]; then
                VISUAL_INDEX=$(echo "$DESKTOP_NAME_STR" | cut -d':' -f1 | tr -d ' ')
            fi

            printf "\n# ================= DESKTOP %s (VISUAL INDEX: %s | NAME: %s) =================\n" "$NEW_DESKTOP" "$VISUAL_INDEX" "$DESKTOP_NAME_STR" >> "$DATA_FILE"

            CURRENT_DESKTOP="$NEW_DESKTOP"
            CURRENT_MONITOR=""
        fi

        WINDOW_BLOCK_BUFFER+="$line"$'\n'

    elif [[ "$line" == WINDOW_?*_MONITOR=* ]]; then
        NEW_MONITOR=${line##*=}

        if [ "$NEW_MONITOR" != "$CURRENT_MONITOR" ]; then
            MONITOR_NAME_STR=${MONITOR_NAME[$NEW_MONITOR]:-""}

            printf "\n# ------------- MONITOR %s (%s) -------------\n" "$NEW_MONITOR" "$MONITOR_NAME_STR" >> "$DATA_FILE"
            CURRENT_MONITOR="$NEW_MONITOR"
        fi

        WINDOW_BLOCK_BUFFER+="$line"$'\n'

    elif [[ "$line" == WINDOW_?*_WID=* ]]; then
        WINDOW_INDEX=$(echo "$line" | cut -d'_' -f2)

        printf "\n# --- WINDOW %s ---\n" "$WINDOW_INDEX" >> "$DATA_FILE"

        printf "%s" "$WINDOW_BLOCK_BUFFER" >> "$DATA_FILE"
        WINDOW_BLOCK_BUFFER=""

        printf "%s\n" "$line" >> "$DATA_FILE"

    else
        printf "%s\n" "$line" >> "$DATA_FILE"
    fi

done < "$TEMP_FINAL_DATA"

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "DATA STATE SUCCESSFULLY BACKED UP."

# --- TERMINAL FEEDBACK ---
printf "✅ M03 SUCCESS: Captured %s active window(s) with Desktop/Monitor/Window hierarchy.\n" "$FINAL_WINDOW_COUNT_REINDEXED"
log "MODULE 03 END (SUCCESS)"
exit 0