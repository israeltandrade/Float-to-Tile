#!/usr/bin/env bash

# File: 06_Window-Cycle-Map.sh
# Description: Reads the window list (M03) and floating list (M05) to generate
#              deterministic focus-cycle lists, grouped by Desktop and Monitor.
#              The ordering within groups is determined by the global
#              WINDOW_CYCLE_ORDER configuration (e.g., TITLE, TIMESTAMP).
#
#              TIMESTAMP ORDER (Highest Priority First, Descending Sort):
#              1. USER_TIME (Last Interaction)
#              2. PROCESS_START_TIME (As fallback for USER_TIME=0)
#
# Output: Data/06_Window-Cycle-Map.data (e.g., D0_M1_CYCLE_LIST="WID1 WID2...")

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
LAST_STATE_DIR="$ROOT_DIR/Last-Valid-States"

DESKTOP_DATA_FILE="$DATA_DIR/02_Desktop-Details.data"
WINDOW_DATA_FILE="$DATA_DIR/03_Window-List.data"
FLOATING_DATA_FILE="$DATA_DIR/05_Floating-WIDs.data"
MONITOR_DATA_FILE="$DATA_DIR/01_Screen-Resolution.data"

LOG_FILE="$LOG_DIR/06_Window-Cycle-Map.log"
DATA_FILE="$DATA_DIR/06_Window-Cycle-Map.data"
LAST_VALID_STATE_FILE="$LAST_STATE_DIR/06_Window-Cycle-Map.last-valid-state"

TEMP_FILTERED_DATA="/tmp/06_filtered_data_$$"
MASTER_WID_LIST_RAW="/tmp/06_master_wid_list_$$"

# ===== UTILITY FUNCTIONS =====
log() {
    mkdir -p "$LOG_DIR"
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# ===== Normalization for SORT_KEY (robust) =====
normalize_key() {
    local input="$1"
    local s

    s="${input//\\}"
    s="$(printf '%s' "$s" | tr -d '\000-\037')"

    if command -v iconv >/dev/null 2>&1; then
        s="$(printf '%s' "$s" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null || printf '%s' "$s")"
    fi

    s="$(printf '%s' "$s" | sed 's/[^[:alnum:][:space:]]/ /g')"
    s="$(printf '%s' "$s" | sed -E 's/[[:space:]]+/ /g')"
    s="$(printf '%s' "$s" | sed -E 's/^ //; s/ $//')"
    s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"

    if [[ -z "$s" ]]; then
        printf 'zz_empty_title'
    else
        printf '%s' "$s"
    fi
}

# ===== Heuristic: filename/ID detection =====
looks_like_filename_or_id() {
    local t="$1"
    if [[ "$t" =~ ^[0-9] ]] || [[ "$t" == *"."* ]] || [[ "$t" == *"/"* ]] || [[ "$t" == *"_"* ]]; then
        return 0
    fi
    if printf '%s' "$t" | grep -qiE '^sem titulo|^sem título'; then
        return 0
    fi
    if printf '%s' "$t" | grep -qE '[0-9]{2,}'; then
        return 0
    fi
    return 1
}

# ===== Read monitor names =====
read_monitor_names() {
    if [[ -f "$MONITOR_DATA_FILE" ]]; then
        MONITOR_COUNT=$(grep '^MONITOR_COUNT=' "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        if ! [[ "$MONITOR_COUNT" =~ ^[0-9]+$ ]]; then
            MONITOR_COUNT=0
        fi
        local m_idx=1
        while [ "$m_idx" -le "$MONITOR_COUNT" ]; do
            MONITOR_NAME[$m_idx]=$(grep "^MONITOR_${m_idx}_NAME=" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
            MONITOR_NAME[$m_idx]="$(printf '%s' "${MONITOR_NAME[$m_idx]}" | sed -E "s/^['\"]?//; s/['\"]?$//; s/^ *//; s/ *$//")"
            m_idx=$((m_idx + 1))
        done
    fi
}

: > "$LOG_FILE"
declare -A CYCLE_MAP
declare -A IS_FLOATING
declare -A DESKTOP_NAME_MAP
declare -a MONITOR_NAME
trap 'rm -f "$TEMP_FILTERED_DATA" "$MASTER_WID_LIST_RAW"' EXIT
log "MODULE 06 START (v1.9 - Subshell Fix + SORT_KEY normalization + smart title heuristics + RESOURCE priority)"

# ===== 2. LOAD DEPENDENCIES =====
if [[ -f "$CONFIG_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE" 2>/dev/null || true
    WINDOW_CYCLE_ORDER="${WINDOW_CYCLE_ORDER:-RAW}"
    log "INFO: Loaded configuration. WINDOW_CYCLE_ORDER is set to $WINDOW_CYCLE_ORDER."
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Falling back to RAW order."
    WINDOW_CYCLE_ORDER="RAW"
fi

if [[ -f "$FLOATING_DATA_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$FLOATING_DATA_FILE" 2>/dev/null
    log "INFO: Loaded Floating WID list."
else
    log "ERROR: Required data file not found: $FLOATING_DATA_FILE."
    printf "❌ M06 FAILED: Floating WID data file not found.\n"
    exit 1
fi

if [[ -f "$DESKTOP_DATA_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$DESKTOP_DATA_FILE" 2>/dev/null
    log "INFO: Loaded Desktop Details for name mapping."
    
    if [ -n "${DESKTOP_COUNT:-}" ] && [ "$DESKTOP_COUNT" -gt 0 ]; then
        for ((i = 0; i < DESKTOP_COUNT; i++)); do
            NAME_VAR="DESKTOP_${i}_NAME"
            NAME=${!NAME_VAR:-'Unknown Name'}
            DESKTOP_NAME_MAP["$i"]="$NAME"
        done
    fi
else
    log "ERROR: Desktop details data file not found at $DESKTOP_DATA_FILE."
    printf "❌ M06 FAILED: Missing desktop details data.\n"
    exit 1
fi

read_monitor_names
log "INFO: Loaded Monitor Names (MONITOR_COUNT=${MONITOR_COUNT:-0})."

if [[ -f "$WINDOW_DATA_FILE" ]]; then
    grep -E "^(WINDOW_COUNT|WINDOW_[0-9]+_(WID|DESKTOP|MONITOR|CLASS|RESOURCE|TITLE|USER_TIME|PROCESS_START_TIME|WINDOW_FIRST_SEEN_MS|PID))=" "$WINDOW_DATA_FILE" > "$TEMP_FILTERED_DATA"
    
    if [ -s "$TEMP_FILTERED_DATA" ]; then
        # shellcheck source=/dev/null
        source "$TEMP_FILTERED_DATA" 2>/dev/null
        log "INFO: Loaded and filtered window list data (including new WINDOW_FIRST_SEEN_MS)."
    else
        log "WARNING: Window list file is empty or contains no valid data."
        WINDOW_COUNT=0
    fi
else
    log "ERROR: Window list data file not found at $WINDOW_DATA_FILE."
    printf "❌ M06 FAILED: Missing window list data.\n"
    exit 1
fi

# ===== 3. BUILD FLOATING WID LOOKUP TABLE =====
if [[ -n "${FLOAT_WID_LIST:-}" ]]; then
    OLD_IFS=$IFS
    IFS=',' 
    read -ra FLOAT_WID_ARRAY <<< "$FLOAT_WID_LIST"
    IFS=$OLD_IFS
    
    for wid in "${FLOAT_WID_ARRAY[@]}"; do
        if [[ -n "$wid" ]]; then
            IS_FLOATING["$wid"]=1
        fi
    done
    log "DEBUG: Initialized floating WID lookup table (${#IS_FLOATING[@]} items)."
fi

# ===== 4. DETERMINE SORT CONFIGURATION =====
SORT_FIELD=""
SORT_FLAG=""

case "$WINDOW_CYCLE_ORDER" in
    ALPHABETICAL_ASC)
        SORT_FIELD="TITLE"
        SORT_FLAG="f"
        ;;
    ALPHABETICAL_DESC)
        SORT_FIELD="TITLE"
        SORT_FLAG="fr"
        ;;
    TIMESTAMP)
        SORT_FIELD="USER_TIME"
        SORT_FLAG="r"
        ;;
    INVERTED_TIMESTAMP)
        SORT_FIELD="USER_TIME"
        SORT_FLAG=""
        ;;
    *)
        SORT_FIELD="WID"
        SORT_FLAG=""
        ;;
esac

# ===== 5. BUILD SORTABLE WID LIST =====
log "INFO: Building sortable window list (DESKTOP|MONITOR|WID|SORT_KEY|WINDOW_DISPLAY_NAME)."

: > "$MASTER_WID_LIST_RAW"

if [ -n "${WINDOW_COUNT:-}" ] && [ "$WINDOW_COUNT" -gt 0 ]; then
    for ((i = 1; i <= WINDOW_COUNT; i++)); do
        WID_VAR="WINDOW_${i}_WID"
        DESKTOP_VAR="WINDOW_${i}_DESKTOP"
        MONITOR_VAR="WINDOW_${i}_MONITOR"
        CLASS_VAR="WINDOW_${i}_CLASS"
        RESOURCE_VAR="WINDOW_${i}_RESOURCE"
        TITLE_VAR="WINDOW_${i}_TITLE"
        USER_TIME_VAR="WINDOW_${i}_USER_TIME"
        P_START_TIME_VAR="WINDOW_${i}_PROCESS_START_TIME"
        W_FIRST_SEEN_VAR="WINDOW_${i}_WINDOW_FIRST_SEEN_MS"
        PID_VAR="WINDOW_${i}_PID"
        
        WID=${!WID_VAR}
        DESKTOP_ID=${!DESKTOP_VAR}
        MONITOR_ID=${!MONITOR_VAR}
        CLASS=${!CLASS_VAR:-}
        RESOURCE=${!RESOURCE_VAR:-}
        TITLE=${!TITLE_VAR:-}
        USER_TIME=${!USER_TIME_VAR:-0}
        P_START_TIME=${!P_START_TIME_VAR:-0}
        W_FIRST_SEEN=${!W_FIRST_SEEN_VAR:-0}
        PID=${!PID_VAR:-0}
        
        if [[ -z "${WID:-}" ]]; then
            log "WARNING: Skipping window index $i due to empty WID."
            continue
        fi
        
        if [[ ${IS_FLOATING["$WID"]+x} ]]; then
            continue 
        fi
        
        SIMPLE_TITLE=$(echo "$TITLE" | sed 's/ *[—–:\-].*//; s/ *(\(PWA\|Web App\)).*//' | sed 's/^ *//; s/ *$//')
        
        WINDOW_DISPLAY_NAME=""
        if [[ "${CLASS}" == "com" ]]; then
            CLEAN_TITLE="${TITLE//\\}"
            WINDOW_DISPLAY_NAME=$(printf '%b' "$CLEAN_TITLE" 2>/dev/null || echo "$CLEAN_TITLE")
        else
            if [[ -z "$SIMPLE_TITLE" && -n "$TITLE" ]]; then
                CLEAN_TITLE="${TITLE//\\}"
                SIMPLE_TITLE=$(printf '%b' "$CLEAN_TITLE" 2>/dev/null || echo "$CLEAN_TITLE")
            fi

            if [[ -n "$SIMPLE_TITLE" ]]; then
                if looks_like_filename_or_id "$SIMPLE_TITLE"; then
                    WINDOW_DISPLAY_NAME="${RESOURCE:-${CLASS:-'Unknown Window'}}"
                else
                    WINDOW_DISPLAY_NAME="$SIMPLE_TITLE"
                fi
            else
                WINDOW_DISPLAY_NAME="${RESOURCE:-${CLASS:-'Unknown Window'}}"
            fi
        fi

        SORT_KEY=""
        if [ "$SORT_FIELD" = "TITLE" ]; then
            SORT_KEY_RAW="${SIMPLE_TITLE:-${WINDOW_DISPLAY_NAME}}"
            SORT_KEY="$(normalize_key "$SORT_KEY_RAW")"
        elif [ "$SORT_FIELD" = "USER_TIME" ]; then
            SORT_KEY_USER_TIME=$(printf "%020d" "$USER_TIME")
            SORT_KEY_P_START=$(printf "%020d" "$P_START_TIME")
            TIEBREAKER="$(normalize_key "${SIMPLE_TITLE:-${WINDOW_DISPLAY_NAME}}")"
            SORT_KEY="${SORT_KEY_USER_TIME}_${SORT_KEY_P_START}_${TIEBREAKER}"
        else
            SORT_KEY="$WID"
        fi
        
        printf "%s|%s|%s|%s|%s\n" "$DESKTOP_ID" "$MONITOR_ID" "$WID" "${SORT_KEY:-$WID}" "$WINDOW_DISPLAY_NAME" >> "$MASTER_WID_LIST_RAW"
    done
fi

# ===== 6. APPLY CUSTOM SORT =====
if [ -s "$MASTER_WID_LIST_RAW" ]; then
    log "INFO: Applying custom sort based on WINDOW_CYCLE_ORDER: $WINDOW_CYCLE_ORDER. Sort Flag: $SORT_FLAG."

    SORT_COMMAND="LC_ALL=C sort -t'|' -k1,1n -k2,2n -k4,4$SORT_FLAG $MASTER_WID_LIST_RAW -o $MASTER_WID_LIST_RAW"
    
    log "DEBUG: Executing sort command: $SORT_COMMAND"
    eval "$SORT_COMMAND"
else
    log "WARNING: No non-floating windows found for sorting. Outputting empty map."
fi

# ===== 7. REBUILD CYCLE_MAP FROM SORTED LIST =====
log "INFO: Rebuilding CYCLE_MAP from sorted list."
declare -a SORTED_KEYS=()
LAST_KEY=""

while IFS='|' read -r DESKTOP_ID MONITOR_ID WID SORT_KEY WINDOW_NAME; do
    DESKTOP_ID=$(echo "$DESKTOP_ID" | tr -d '\r')
    MONITOR_ID=$(echo "$MONITOR_ID" | tr -d '\r')
    WID=$(echo "$WID" | tr -d '\r')
    WINDOW_NAME=$(echo "$WINDOW_NAME" | tr -d '\r')

    KEY="D${DESKTOP_ID}_M${MONITOR_ID}"
    ENTRY="$WID|$WINDOW_NAME"
    
    if [[ "$KEY" != "$LAST_KEY" ]]; then
        SORTED_KEYS+=("$KEY")
        LAST_KEY="$KEY"
        CYCLE_MAP["$KEY"]="$ENTRY"
    else
        CYCLE_MAP["$KEY"]+=$'\n'"$ENTRY"
    fi
done < <(cat "$MASTER_WID_LIST_RAW")

# ===== 8. OUTPUT GENERATION =====
: > "$DATA_FILE"
TOTAL_GROUPS=0

for KEY in "${SORTED_KEYS[@]}"; do
    ENTRY_LIST_STR="${CYCLE_MAP[$KEY]}"
    
    DESKTOP_ID=$(echo "$KEY" | cut -d'_' -f1 | tr -d 'D')
    MONITOR_ID=$(echo "$KEY" | cut -d'_' -f2 | tr -d 'M')
    
    DESKTOP_CONTEXT="${DESKTOP_NAME_MAP["$DESKTOP_ID"]:-'Unknown Desktop'}"
    
    VISUAL_INDEX="$(echo "$DESKTOP_CONTEXT" | cut -d':' -f1 | sed 's/^ *//; s/ *$//')"
    
    COUNT=0
    WID_LIST_ONLY=""
    HUMAN_READABLE_BLOCK=""
    WINDOW_COUNTER=0

    while IFS= read -r entry; do
        if [[ -n "$entry" ]]; then
            WINDOW_COUNTER=$((WINDOW_COUNTER + 1))
            COUNT=$((COUNT + 1))
            
            WID=$(echo "$entry" | cut -d'|' -f1)
            WINDOW_NAME=$(echo "$entry" | cut -d'|' -f2-)
            
            WID_LIST_ONLY+="$WID "
            HUMAN_READABLE_BLOCK+=$'\n'"# --- WINDOW ${WINDOW_COUNTER} ---"
            HUMAN_READABLE_BLOCK+=$'\n'"#   DESKTOP=${DESKTOP_ID}"
            HUMAN_READABLE_BLOCK+=$'\n'"#   MONITOR=${MONITOR_ID}"
            HUMAN_READABLE_BLOCK+=$'\n'"#   WID=${WID}"
            HUMAN_READABLE_BLOCK+=$'\n'"#   NAME=${WINDOW_NAME}"
        fi
    done <<< "$ENTRY_LIST_STR"
    
    if [ "$COUNT" -gt 0 ]; then
        printf "\n# ================= DESKTOP %s (VISUAL INDEX: %s | NAME: %s) =================\n" "$DESKTOP_ID" "$VISUAL_INDEX" "$DESKTOP_CONTEXT" >> "$DATA_FILE"
        printf "\n# ------------- MONITOR %s (%s) -------------\n" "$MONITOR_ID" "${MONITOR_NAME[$MONITOR_ID]:-UnknownMonitor}" >> "$DATA_FILE"

        printf "%s\n" "$HUMAN_READABLE_BLOCK" >> "$DATA_FILE"

        printf "\n# WINDOWS COUNT: %s\n" "$COUNT" >> "$DATA_FILE"
        printf "%s_CYCLE_LIST='%s'\n" "$KEY" "$(echo $WID_LIST_ONLY | xargs)" >> "$DATA_FILE"
        printf "%s_COUNT=%s\n" "$KEY" "$COUNT" >> "$DATA_FILE"

        log "INFO: Generated map for $KEY ($COUNT windows) using $WINDOW_CYCLE_ORDER order."
        TOTAL_GROUPS=$((TOTAL_GROUPS + 1))
    fi
done

# ===== 9. STATE PERSISTENCE =====
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "INFO: Data state successfully backed up."

printf "✅ M06 SUCCESS: Generated cycle maps for %s window groups using %s order.\n" "$TOTAL_GROUPS" "$WINDOW_CYCLE_ORDER"
log "MODULE 06 END - SUCCESS"
exit 0