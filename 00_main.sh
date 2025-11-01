#!/usr/bin/env bash

# --- Configuration ---
SCRIPT_DIR="$(dirname "$0")"
MAIN_LOG_FILE="./00_main.log"
ORCHESTRATION_FAILED=0

# --- Utility Functions ---

main_log() {
    local message="$1"
    printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$message" >> "$MAIN_LOG_FILE"
}

check_status() {
    local exit_code=$?
    local module_path="$1"
    local module_name="$(basename "$module_path")"

    if [ "$exit_code" -ne 0 ]; then
        printf "❌ %s FAILED (Exit Code: %s)\n" "$module_name" "$exit_code"
        main_log "MODULE FAILURE: $module_name returned $exit_code."
        ORCHESTRATION_FAILED=1
    else
        printf "✅ %s SUCCESS\n" "$module_name"
        main_log "MODULE SUCCESS: $module_name."
    fi
}

# --- Initialization ---

: > "$MAIN_LOG_FILE"
main_log "ORCHESTRATION START"

# --- Orchestration Loop ---
printf -- "--- Starting Float-to-Tile Modules ---\n"

for module_path in "$SCRIPT_DIR"/??_*.sh; do
    
    module_name=$(basename "$module_path")
    
    if [[ "$module_name" == "00_main.sh" ]]; then
        continue 
    fi

    printf "▶ Executing %s...\n" "$module_name"

    "$module_path" 
    
    check_status "$module_path"
    
done

# --- Finalization ---

if [ "$ORCHESTRATION_FAILED" -eq 1 ]; then
    main_log "ORCHESTRATION COMPLETE (WITH FAILURES)"
    printf "\n--- Float-to-Tile Collection Complete (WITH FAILURES) ---\n"
    exit 1
else
    main_log "ORCHESTRATION COMPLETE (SUCCESS)"
    printf "\n--- Float-to-Tile Collection Complete (SUCCESS) ---\n"
    exit 0
fi