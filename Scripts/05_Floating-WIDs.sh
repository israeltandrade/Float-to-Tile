#!/usr/bin/env bash

# File: 05_Floating-WIDs.sh
# Description: Identifies Window IDs (WIDs) that should remain floating based on
#              rules in global_config.conf (FLOAT_CLASSES, FLOAT_RESOURCES).
# Dependencies: 03_Window-List.data, global_config.conf.
# Output: Data/05_Floating-WIDs.data (defines FLOAT_WID_LIST and FLOAT_WID_COUNT)

set -euo pipefail
IFS=$'\n\t'

# ===== 1. INITIALIZATION & PATHS =====

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ===== DIRECTORY GUARANTEE =====
mkdir -p "$ROOT_DIR/Logs" \
         "$ROOT_DIR/Data" \
         "$ROOT_DIR/Last-Valid-States"

CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_DIR="$ROOT_DIR/Logs"
WINDOW_DATA_FILE="$DATA_DIR/03_Window-List.data"

LOG_FILE="$LOG_DIR/05_Floating-WIDs.log"
DATA_FILE="$DATA_DIR/05_Floating-WIDs.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/Last-Valid-States/05_Floating-WIDs.last-valid-state"

TEMP_FILTERED_DATA="/tmp/05_filtered_data_$$"
TEMP_FINAL_DATA="/tmp/05_temp_final_data_$$"

# ===== UTILITY FUNCTIONS =====
log() {
    mkdir -p "$LOG_DIR"
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# ===== INITIALIZATION & CLEANUP =====
: > "$LOG_FILE"
: > "$TEMP_FINAL_DATA"
declare -a FLOATING_WIDS=()

cleanup() {
    local exit_code=$?
    rm -f "$TEMP_FINAL_DATA"
    
    if [ "$exit_code" -ne 0 ] && [ -f "$TEMP_FILTERED_DATA" ]; then
        printf -- "\n\n⚠️ DIAGNOSTIC: Module 05 FAILED (Exit Code: %s).\n" "$exit_code"
        printf -- "The temporary file broke the 'source' and has been RETAINED for inspection.\n"
        printf -- "CHECK CONTENT at: %s\n\n" "$TEMP_FILTERED_DATA"
    else
        rm -f "$TEMP_FILTERED_DATA"
    fi
}

trap cleanup EXIT
log "Module 05 START (Floating Window Filter)"

# ===== 2. LOAD CONFIGURATION AND DEPENDENCIES =====

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log "INFO: Loaded configuration (FLOAT_CLASSES, FLOAT_RESOURCES)."
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    printf "❌ M05 FAILED: Configuration file not found.\n"
    exit 1
fi

if [[ -f "$WINDOW_DATA_FILE" ]]; then
    grep -E '^(WINDOW_COUNT=|WINDOW_[0-9]+_[A-Z_]+=)' "$WINDOW_DATA_FILE" > "$TEMP_FILTERED_DATA"
    source "$TEMP_FILTERED_DATA"
    log "INFO: Loaded window list data from $WINDOW_DATA_FILE (filtered safely)."
else
    log "ERROR: Window list data file not found at $WINDOW_DATA_FILE. Exiting."
    printf "❌ M05 FAILED: Missing window list data.\n"
    exit 1
fi

# ===== 3. FILTERING LOGIC =====

OLD_IFS=$IFS
IFS=','
read -ra FLOAT_CLASS_LIST <<< "${FLOAT_CLASSES:-}"
read -ra FLOAT_RESOURCE_LIST <<< "${FLOAT_RESOURCES:-}"
IFS=$OLD_IFS

log "DEBUG: Floating Classes configured: ${FLOAT_CLASS_LIST[*]}"
log "DEBUG: Floating Resources configured: ${FLOAT_RESOURCE_LIST[*]}"

for ((i = 1; i <= WINDOW_COUNT; i++)); do
    WINDOW_WID_VAR="WINDOW_${i}_WID"
    WINDOW_CLASS_VAR="WINDOW_${i}_CLASS"
    WINDOW_RESOURCE_VAR="WINDOW_${i}_RESOURCE"
    
    WID=${!WINDOW_WID_VAR}
    CLASS=${!WINDOW_CLASS_VAR}
    RESOURCE=${!WINDOW_RESOURCE_VAR}
    
    SHOULD_FLOAT="false"

    for fc in "${FLOAT_CLASS_LIST[@]}"; do
        if [[ -z "$fc" ]]; then continue; fi 
        if [[ "$CLASS" == *"$fc"* ]]; then
            SHOULD_FLOAT="true"
            log "INFO: Window $WID ($CLASS) marked floating by CLASS rule (Match: $fc)."
            break
        fi
    done
    
    if [[ "$SHOULD_FLOAT" == "false" ]]; then
        for fr in "${FLOAT_RESOURCE_LIST[@]}"; do
            if [[ -z "$fr" ]]; then continue; fi 
            if [[ "$RESOURCE" == *"$fr"* ]]; then
                SHOULD_FLOAT="true"
                log "INFO: Window $WID ($RESOURCE) marked floating by RESOURCE rule (Match: $fr)."
                break
            fi
        done
    fi

    if [[ "$SHOULD_FLOAT" == "true" ]]; then
        FLOATING_WIDS+=("$WID")
    fi
done

# ===== 4. OUTPUT GENERATION =====

FLOAT_WID_COUNT=${#FLOATING_WIDS[@]}
FLOAT_WID_LIST=$(IFS=','; echo "${FLOATING_WIDS[*]}")

printf "FLOAT_WID_COUNT=%s\n" "$FLOAT_WID_COUNT" > "$DATA_FILE"
printf "FLOAT_WID_LIST='%s'\n" "$FLOAT_WID_LIST" >> "$DATA_FILE"

# ===== 5. STATE PERSISTENCE =====
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."

log "INFO: Total windows to ignore (floating): $FLOAT_WID_COUNT"
log "INFO: FLOAT_WID_LIST: $FLOAT_WID_LIST"

printf "✅ M05 SUCCESS: Identified %s floating window WIDs.\n" "$FLOAT_WID_COUNT"
log "Module 05 END (SUCCESS)"
exit 0