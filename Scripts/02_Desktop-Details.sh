#!/usr/bin/env bash

# File: 02_Desktop-Details.sh (v1.8 - Robust ACTIVE_DESKTOP capture)
# Description: Captures desktop (workspace) details including names and the active desktop index.
# Dependencies: wmctrl, awk, date, xprop.

set -euo pipefail
IFS=$'\n\t'

# ===== PATH CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ===== DIRECTORY GUARANTEE =====
mkdir -p "$ROOT_DIR/Logs" \
         "$ROOT_DIR/Data" \
         "$ROOT_DIR/Last-Valid-States"

LOG_FILE="$ROOT_DIR/Logs/02_Desktop-Details.log"
DATA_FILE="$ROOT_DIR/Data/02_Desktop-Details.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/Last-Valid-States/02_Desktop-Details.last-valid-state"

# ===== UTILITY FUNCTIONS =====
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# ===== INITIALIZATION =====
: > "$LOG_FILE"
log "MODULE 02 START (v1.8 - Robust ACTIVE_DESKTOP capture)"

# ===== DEPENDENCY CHECK =====
if ! command -v wmctrl &> /dev/null; then
    log "FAILURE: wmctrl command not found."
    printf "❌ M02 FAILED: wmctrl command not found. Please install wmctrl.\n"
    exit 1
fi

# ===== DATA ACQUISITION =====

# ===== GET DESKTOP COUNT AND NAMES =====
log "Executing wmctrl -d to get desktop count and names..."
WMCTRL_D_OUTPUT=$(wmctrl -d 2>/dev/null)

if [ -z "$WMCTRL_D_OUTPUT" ]; then
    log "FAILURE: 'wmctrl -d' returned empty output."
    printf "❌ M02 FAILED: 'wmctrl -d' output is empty.\n"
    exit 1
fi

DESKTOP_COUNT=$(echo "$WMCTRL_D_OUTPUT" | wc -l)

# ===== PARSE DESKTOP NAMES AND COUNT =====
log "Parsing desktop names and count ($DESKTOP_COUNT)..."
printf "DESKTOP_COUNT=%s\n" "$DESKTOP_COUNT" > "$DATA_FILE"
DESKTOP_INDEX=0

while read -r line; do
    desktop_index=$(echo "$line" | awk '{print $1}')
    desktop_name=$(echo "$line" | sed 's/.*WA:[^ ]* [^ ]* *//')
    
    if [[ "$desktop_index" =~ ^[0-9]+$ ]]; then
        if [ -z "$desktop_name" ]; then
             desktop_name="Desktop $DESKTOP_INDEX"
        fi
        
        printf "DESKTOP_%s_NAME='%s'\n" "$desktop_index" "$desktop_name" >> "$DATA_FILE"
        DESKTOP_INDEX=$((DESKTOP_INDEX + 1))
    fi
done <<< "$WMCTRL_D_OUTPUT"

# ===== DETERMINE ACTIVE_DESKTOP =====
log "Attempting to read ACTIVE_DESKTOP using '*' marker in wmctrl -d..."
ACTIVE_DESKTOP=$(echo "$WMCTRL_D_OUTPUT" | awk '/\*/ {print $1; exit}')

if [ -z "$ACTIVE_DESKTOP" ]; then
    log "Fallback: '*' marker failed, attempting to read _NET_CURRENT_DESKTOP via xprop..."
    ACTIVE_DESKTOP=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk -F'= ' '/_NET_CURRENT_DESKTOP/ {print $2; exit}')
    ACTIVE_DESKTOP=$(echo "$ACTIVE_DESKTOP" | tr -d '[:space:]' | sed 's/0x//g')
    
    if [[ "$ACTIVE_DESKTOP" =~ ^[0-9]+$ ]]; then
        log "Fallback success: Active Desktop found via xprop: $ACTIVE_DESKTOP"
    else
        ACTIVE_DESKTOP=""
        log "Fallback failed: xprop did not return a clean numeric desktop index."
    fi
fi

if [ -z "$ACTIVE_DESKTOP" ]; then
    log "WARNING: Could not determine ACTIVE_DESKTOP. Defaulting to 0."
    ACTIVE_DESKTOP=0
fi

log "Final ACTIVE_DESKTOP value: $ACTIVE_DESKTOP"
printf "ACTIVE_DESKTOP=%s\n" "$ACTIVE_DESKTOP" >> "$DATA_FILE"

# ===== OUTPUT GENERATION AND STATE PERSISTENCE =====
if [ "$DESKTOP_COUNT" -gt 0 ]; then
    cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
    log "DATA STATE SUCCESSFULLY BACKED UP."
    
    printf "✅ M02 SUCCESS: Captured %s desktop details.\n" "$DESKTOP_COUNT"
    log "MODULE 02 END (SUCCESS)"
    exit 0
else
    log "FAILURE: Desktop count is 0 after processing."
    printf "❌ M02 FAILED: Desktop count is zero.\n"
    exit 1
fi