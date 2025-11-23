#!/bin/bash
# File: AC06_Monocle.sh
# Description: v1.8 - Clean, safe, no-sticky. Applies the Monocle layout for windows on the ACTIVE_DESKTOP only.
# Notes:
# - Ignores sticky windows (DESKTOP==-1).
# - Atomic write for last-valid-state (overwrites).
# - IFS-safe splitting for WID lists.
# - Terminal grid safety shrink for xfce4-terminal.

set -euo pipefail
IFS=$'\n\t'

# ===== INITIALIZATION & PATHS =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC06_Monocle.log"
STATE_FILE="$ROOT_DIR/Actions/Actions_Last-Valid-States/AC06_Monocle.last-valid-state"
LAST_STATE_DIR="$ROOT_DIR/Actions/Actions_Last-Valid-States"
LAST_STATE_FILE="${LAST_STATE_FILE:-$LAST_STATE_DIR/AC06_Monocle.last-valid-state}"
FLOAT_DATA_FILE="$ROOT_DIR/Data/05_Floating-WIDs.data"

# ===== ENSURE DIRECTORIES =====
if ! mkdir -p "$(dirname "$LOG_FILE")"; then
    echo "ERROR: cannot create log directory: $(dirname "$LOG_FILE")" >&2
    exit 1
fi

if ! mkdir -p "$LAST_STATE_DIR"; then
    echo "ERROR: cannot create last-state directory: $LAST_STATE_DIR" >&2
    exit 1
fi

# ===== LOGGING =====
log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [AC06_Monocle] - $1" >> "$LOG_FILE"
}

: > "$LOG_FILE"
log "INFO: Script started (v1.8 Clean)."

# ===== LOAD CONFIGURATION =====
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    exit 1
fi

# ===== UPDATE ENVIRONMENT DATA =====
if ! "$ROOT_DIR/run.sh"; then
    log "ERROR: run.sh failed to update environment data. Exiting."
    exit 1
fi

# ===== REQUIRE DATA FILES =====
if [[ -f "$DATA_DIR/01_Screen-Resolution.data" ]] && \
   [[ -f "$DATA_DIR/02_Desktop-Details.data" ]] && \
   [[ -f "$DATA_DIR/03_Window-List.data" ]] && \
   [[ -f "$DATA_DIR/04_Monitor-Area.data" ]] && \
   [[ -f "$DATA_DIR/06_Window-Cycle-Map.data" ]]; then

    source "$DATA_DIR/01_Screen-Resolution.data"
    source "$DATA_DIR/02_Desktop-Details.data"
    source "$DATA_DIR/03_Window-List.data"
    source "$DATA_DIR/04_Monitor-Area.data"
    source "$DATA_DIR/06_Window-Cycle-Map.data"
else
    log "ERROR: Required data files (01,02,03,04,06) not found. Exiting."
    exit 1
fi

# ===== LOAD FLOATING WIDS =====
FLOAT_WID_LIST=""
if [[ -f "$FLOAT_DATA_FILE" ]]; then
    FLOAT_WID_LIST=$(grep '^FLOAT_WID_LIST=' "$FLOAT_DATA_FILE" | sed -n "s/FLOAT_WID_LIST='\(.*\)'/\1/p" || true)
fi

# ===== BUILD MAP OF TILEABLE WIDS PER MONITOR (ACTIVE DESKTOP ONLY) =====
CURRENT_GEOMETRY_STATE=""
TOTAL_TILED_WINDOWS=0

declare -A TILE_WIDS_BY_MONITOR
declare -A MAP_WID_CLASS
declare -A MAP_WID_TITLE

ACTIVE_DESK="${ACTIVE_DESKTOP:-0}"
log "INFO: ACTIVE_DESKTOP=${ACTIVE_DESK}"

for ((i = 1; i <= ${WINDOW_COUNT:-0}; i++)); do
    DESKTOP_VAR="WINDOW_${i}_DESKTOP"; DESKTOP=${!DESKTOP_VAR:-}
    WID_VAR="WINDOW_${i}_WID"; WID=${!WID_VAR:-}
    MONITOR_VAR="WINDOW_${i}_MONITOR"; MONITOR_ID=${!MONITOR_VAR:-}
    GEOM_VAR="WINDOW_${i}_GEOMETRY"; GEOM=${!GEOM_VAR:-}
    TITLE_VAR="WINDOW_${i}_TITLE"; TITLE_Q=${!TITLE_VAR:-}
    CLASS_VAR="WINDOW_${i}_CLASS"; CLASS=${!CLASS_VAR:-}

    sanitized="${TITLE_Q//[$'\r\n']/ }"
    sanitized="${sanitized//$'\t'/ }"

    if [[ -n "$WID" && -n "$GEOM" ]]; then
        CURRENT_GEOMETRY_STATE+="${WID}:${GEOM} "
    fi

    if [[ -n "$WID" ]]; then
        MAP_WID_CLASS["$WID"]="${CLASS:-unknown}"
        MAP_WID_TITLE["$WID"]="${sanitized:-unknown}"
    fi

    if [[ -z "$DESKTOP" || -z "$WID" || -z "$MONITOR_ID" ]]; then
        continue
    fi

    if [[ "$DESKTOP" -eq -1 ]]; then
        continue
    fi

    if [[ "$DESKTOP" -ne "$ACTIVE_DESK" ]]; then
        continue
    fi

    if [[ -n "$FLOAT_WID_LIST" && "$FLOAT_WID_LIST" == *"$WID"* ]]; then
        continue
    fi

    if [ -z "${TILE_WIDS_BY_MONITOR[$MONITOR_ID]:-}" ]; then
        TILE_WIDS_BY_MONITOR[$MONITOR_ID]="$WID"
    else
        TILE_WIDS_BY_MONITOR[$MONITOR_ID]+=" $WID"
    fi
done

# ===== SAVE RAW GEOMETRY STATE (ATOMIC) =====
if [ -n "$CURRENT_GEOMETRY_STATE" ]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    tmp_state="$(mktemp "${STATE_FILE}.tmp.XXXXXX")"
    printf "%s\n" "$CURRENT_GEOMETRY_STATE" > "$tmp_state"
    mv -f "$tmp_state" "$STATE_FILE"
    chmod 0644 "$STATE_FILE" 2>/dev/null || true
fi

# ===== APPLY MONOCLE PER MONITOR =====
MONITOR_IDS=$(printf '%s\n' "${!TILE_WIDS_BY_MONITOR[@]}" | sort -n)

for MONITOR_ID in $MONITOR_IDS; do
    WID_LIST="${TILE_WIDS_BY_MONITOR[$MONITOR_ID]:-}"
    if [ -z "$WID_LIST" ]; then continue; fi

    OLD_IFS=$IFS
    IFS=' ' read -ra WIDS_ARRAY <<< "$WID_LIST"
    IFS=$OLD_IFS

    NUM_WINDOWS="${#WIDS_ARRAY[@]}"
    if [ "$NUM_WINDOWS" -eq 0 ]; then continue; fi

    TOTAL_TILED_WINDOWS=$((TOTAL_TILED_WINDOWS + NUM_WINDOWS))
    log "INFO: MONITOR $MONITOR_ID - applying Monocle to $NUM_WINDOWS window(s)."

    X_AREA_VAR="USABLE_AREA_${MONITOR_ID}_X"; X_AREA=${!X_AREA_VAR:-0}
    Y_AREA_VAR="USABLE_AREA_${MONITOR_ID}_Y"; Y_AREA=${!Y_AREA_VAR:-0}
    W_AREA_VAR="USABLE_AREA_${MONITOR_ID}_WIDTH"; W_AREA=${!W_AREA_VAR:-100}
    H_AREA_VAR="USABLE_AREA_${MONITOR_ID}_HEIGHT"; H_AREA=${!H_AREA_VAR:-100}

    GAPED_X=$((X_AREA + GAP_SIZE_PX))
    GAPED_Y=$((Y_AREA + GAP_SIZE_PX))
    GAPED_W=$((W_AREA - 2 * GAP_SIZE_PX))
    GAPED_H=$((H_AREA - 2 * GAP_SIZE_PX))
    if [ "$GAPED_W" -le 0 ]; then GAPED_W=10; GAPED_X=$X_AREA; fi
    if [ "$GAPED_H" -le 0 ]; then GAPED_H=10; GAPED_Y=$Y_AREA; fi

    for WID in "${WIDS_ARRAY[@]}"; do
        wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen' || true

        TARGET_W=$GAPED_W
        TARGET_H=$GAPED_H

        CLASS="${MAP_WID_CLASS[$WID]:-unknown}"
        if [[ "$CLASS" == "xfce4-terminal" ]]; then
            TARGET_W=$((GAPED_W - 5))
            TARGET_H=$((GAPED_H - 40))
        fi

        wmctrl -i -r "$WID" -e 0,"$GAPED_X","$GAPED_Y","$TARGET_W","$TARGET_H" || true
    done

    if [ -n "${ACTIVE_WID:-}" ]; then
        wmctrl -i -a "$ACTIVE_WID" || true
    fi
done

# ===== FINAL USER OUTPUT =====
if [ "$TOTAL_TILED_WINDOWS" -gt 0 ]; then
    echo "✅ AC06 SUCCESS: Monocle Layout Applied (Terminal fix active)."
else
    echo "⚠️ AC06 SKIPPED: No windows found on active desktop."
fi

# ===== SAVE ORGANIZED LAST-VALID-STATE (OVERWRITE, ATOMIC) =====
mkdir -p "$LAST_STATE_DIR"
_payload="$(mktemp "${LAST_STATE_DIR}/AC06_payload.XXXXXX")"

{
    DESK_ID="${ACTIVE_DESK:-0}"
    DESK_NAME_VAR="DESKTOP_${DESK_ID}_NAME"
    DESK_NAME="${!DESK_NAME_VAR:-}"
    printf "=== DESKTOP %s (%s) ===\n" "$DESK_ID" "$DESK_NAME"

    MC="${MONITOR_COUNT:-0}"
    if ! [[ "$MC" =~ ^[0-9]+$ ]]; then MC=0; fi

    if [ "$MC" -gt 0 ]; then
        for MON_ID in $(seq 1 "$MC"); do
            MON_NAME_VAR="MONITOR_${MON_ID}_NAME"
            MON_NAME="${!MON_NAME_VAR:-}"
            printf "\n--- MONITOR %s (%s) ---\n" "$MON_ID" "$MON_NAME"

            VAR="D${DESK_ID}_M${MON_ID}_CYCLE_LIST"
            WID_LIST="${!VAR:-}"
            if [[ -z "$WID_LIST" ]]; then
                WID_LIST="${TILE_WIDS_BY_MONITOR[$MON_ID]:-}"
            fi

            if [[ -z "$WID_LIST" ]]; then
                printf "# Window Names:\n"
                printf "# Windows WIDs:\n\n"
                continue
            fi

            TITLES=""; WIDS_LINE=""
            OLD_IFS=$IFS; IFS=' ' read -ra W_ARR <<< "$WID_LIST"; IFS=$OLD_IFS
            for wid in "${W_ARR[@]}"; do
                t="${MAP_WID_TITLE[$wid]:-unknown}"
                if [[ -z "$TITLES" ]]; then
                    TITLES="$t"
                    WIDS_LINE="${wid}:"
                else
                    TITLES="${TITLES} | ${t}"
                    WIDS_LINE="${WIDS_LINE} ${wid}:"
                fi
            done

            printf "# Window Names: %s\n" "$TITLES"
            printf "# Windows WIDs:\n"
            printf "%s\n" "$WIDS_LINE"
        done
    else
        for MON_ID in $(printf '%s\n' "${!TILE_WIDS_BY_MONITOR[@]}" | sort -n); do
            MON_NAME_VAR="MONITOR_${MON_ID}_NAME"
            MON_NAME="${!MON_NAME_VAR:-}"
            printf "\n--- MONITOR %s (%s) ---\n" "$MON_ID" "$MON_NAME"
            WID_LIST="${TILE_WIDS_BY_MONITOR[$MON_ID]:-}"
            if [[ -z "$WID_LIST" ]]; then
                printf "# Window Names:\n"
                printf "# Windows WIDs:\n\n"
                continue
            fi
            TITLES=""; WIDS_LINE=""
            OLD_IFS=$IFS; IFS=' ' read -ra W_ARR <<< "$WID_LIST"; IFS=$OLD_IFS
            for wid in "${W_ARR[@]}"; do
                t="${MAP_WID_TITLE[$wid]:-unknown}"
                if [[ -z "$TITLES" ]]; then
                    TITLES="$t"
                    WIDS_LINE="${wid}:"
                else
                    TITLES="${TITLES} | ${t}"
                    WIDS_LINE="${WIDS_LINE} ${wid}:"
                fi
            done
            printf "# Window Names: %s\n" "$TITLES"
            printf "# Windows WIDs:\n"
            printf "%s\n" "$WIDS_LINE"
        done
    fi
} > "$_payload"

mv -f "$_payload" "$LAST_STATE_FILE"
chmod 0644 "$LAST_STATE_FILE" 2>/dev/null || true

log "INFO: Last valid state written to $LAST_STATE_FILE"
echo "✅ Last-state written: $LAST_STATE_FILE"