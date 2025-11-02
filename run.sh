#!/usr/bin/env bash

# File: run.sh
# Description: Main orchestrator. Executes modules sequentially, manages workflow, and logs status.

set -euo pipefail
IFS=$'\n\t'

# --- PATH CONFIGURATION ---
SCRIPT_ROOT_DIR="$(dirname "$0")"

LOG_DIR="$SCRIPT_ROOT_DIR/Logs"
SCRIPTS_DIR="$SCRIPT_ROOT_DIR/Scripts"

ORCHESTRATION_FAILED=0

# --- UTILITY FUNCTIONS ---

log() {
    local message="$1"
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$message" >> "$LOG_DIR/run.log"
}

check_status() {
    local exit_code=$?
    local module_path="$1"
    local module_name="$(basename "$module_path")"

    if [ "$exit_code" -ne 0 ]; then
        printf "❌ %s FAILED (EXIT CODE: %s)\n" "$module_name" "$exit_code"
        log "MODULE FAILURE: $module_name RETURNED $exit_code."
        ORCHESTRATION_FAILED=1
    else
        printf "✅ %s SUCCESS\n" "$module_name"
        log "MODULE SUCCESS: $module_name."
    fi
}

# --- INITIALIZATION ---

mkdir -p "$LOG_DIR"
: > "$LOG_DIR/run.log"
log "ORCHESTRATION START"

# --- EXECUTION LOOP ---
printf -- "--- STARTING DATA COLLECTION MODULES ---\n"

for module_path in "$SCRIPTS_DIR"/??_*.sh; do

    if [ ! -e "$module_path" ]; then
        log "WARNING: NO SCRIPTS FOUND IN $SCRIPTS_DIR. SKIPPING LOOP."
        continue
    fi
    
    module_name=$(basename "$module_path")

    printf "▶ EXECUTING %s...\n" "$module_name"

    "$module_path"

    check_status "$module_path"

    if [ "$ORCHESTRATION_FAILED" -eq 1 ]; then
        log "CRITICAL FAILURE: STOPPING EXECUTION SEQUENCE."
        break
    fi

done

# --- FINALIZATION ---

if [ "$ORCHESTRATION_FAILED" -eq 1 ]; then
    log "ORCHESTRATION COMPLETE (WITH FAILURES)"
    printf "\n--- DATA COLLECTION COMPLETE (WITH FAILURES) ---\n"
    exit 1
else
    log "ORCHESTRATION COMPLETE (SUCCESS)"
    printf "\n--- DATA COLLECTION COMPLETE (SUCCESS) ---\n"
    exit 0
fi