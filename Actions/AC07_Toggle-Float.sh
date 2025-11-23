#!/bin/bash
# File: AC07_Toggle-Float.sh
# Description: v3.6. Toggle a window between floating and tiled states. When floating, do NOT force the window 'above' — only change geometry/position.

set -euo pipefail
IFS=$'\n\t'

# ===== INIT & PATHS =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$ROOT_DIR/global_config.conf"

DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC07_Toggle-Float.log"
FLOAT_DATA_FILE="$ROOT_DIR/Data/05_Floating-WIDs.data"
LAST_STATE_DIR="$ROOT_DIR/Actions/Actions_Last-Valid-States"
LAST_STATE_FILE="$LAST_STATE_DIR/AC07_Toggle-Float.last-valid-state"

if ! mkdir -p "$(dirname "$LOG_FILE")"; then
    echo "ERROR: cannot create log directory: $(dirname "$LOG_FILE")" >&2
    exit 1
fi

if ! mkdir -p "$LAST_STATE_DIR"; then
    echo "ERROR: cannot create last-state directory: $LAST_STATE_DIR" >&2
    exit 1
fi

if ! mkdir -p "$(dirname "$FLOAT_DATA_FILE")"; then
    echo "ERROR: cannot create float-data directory: $(dirname "$FLOAT_DATA_FILE")" >&2
    exit 1
fi

# ===== LOGGING =====
log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [AC07_Toggle-Float] - $1" >> "$LOG_FILE"
}

: > "$LOG_FILE"

# ===== LOAD CONFIG =====
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log "INFO: Loaded configuration from $CONFIG_FILE"
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    printf "❌ AC07 FAILED: Configuration file not found.\n"
    exit 1
fi

# ===== GET ACTIVE WID =====
ACTIVE_WID_RAW=$(xprop -root _NET_ACTIVE_WINDOW 2>/dev/null | awk '{print $NF}' | sed 's/,//' || true)

if [[ -z "$ACTIVE_WID_RAW" || "$ACTIVE_WID_RAW" == "0x0" ]]; then
    log "WARNING: xprop returned empty or 0x0. Falling back to xdotool."
    XDOT_DEC=$(xdotool getwindowfocus 2>/dev/null || true)
    if [[ -z "$XDOT_DEC" ]]; then
        log "WARNING: xdotool failed to get focus. Exiting."
        printf "⚠️ AC07 SKIPPED: Please focus a window (WID not found).\n"
        exit 0
    fi
    ACTIVE_WID_RAW="$XDOT_DEC"
fi

ACTIVE_WID_CAN=""
ACTIVE_WID_DEC=0
if [[ -n "$ACTIVE_WID_RAW" ]]; then
    ACTIVE_WID_DEC=$((ACTIVE_WID_RAW))
    ACTIVE_WID_CAN=$(printf '0x%x' "$ACTIVE_WID_DEC")
fi

log "INFO: Active WID raw: $ACTIVE_WID_RAW (decimal: $ACTIVE_WID_DEC, canonical: $ACTIVE_WID_CAN)."

# ===== RUN DATA COLLECTION =====
if ! "$ROOT_DIR/run.sh"; then
    log "ERROR: run.sh failed to update environment data. Exiting."
    printf "❌ AC07 FAILED: Data collection (run.sh) failed.\n"
    exit 1
fi

# ===== LOAD REQUIRED FILES =====
if [[ -f "$DATA_DIR/01_Screen-Resolution.data" ]] && [[ -f "$DATA_DIR/04_Monitor-Area.data" ]] && [[ -f "$DATA_DIR/03_Window-List.data" ]]; then
    source "$DATA_DIR/01_Screen-Resolution.data"
    source "$DATA_DIR/04_Monitor-Area.data"
    source "$DATA_DIR/03_Window-List.data"
    log "INFO: Loaded environment data."
else
    log "ERROR: Required data files not found. Exiting."
    printf "❌ AC07 FAILED: Missing environment data files.\n"
    exit 1
fi

# ===== FIND ACTIVE WINDOW ENTRY IN WINDOW LIST =====
ACTIVE_MONITOR_ID=""
ACTIVE_WIN_X=0
ACTIVE_WIN_Y=0
ACTIVE_WIN_W=0
ACTIVE_WIN_H=0

for ((i = 1; i <= WINDOW_COUNT; i++)); do
    WID_VAR="WINDOW_${i}_WID"
    MONITOR_VAR="WINDOW_${i}_MONITOR"
    X_VAR="WINDOW_${i}_POS_X"
    Y_VAR="WINDOW_${i}_POS_Y"
    W_VAR="WINDOW_${i}_WIDTH"
    H_VAR="WINDOW_${i}_HEIGHT"

    WIN_WID_RAW="${!WID_VAR:-}"
    if [[ -z "$WIN_WID_RAW" ]]; then
        continue
    fi

    WIN_DEC=0
    if ! WIN_DEC=$((WIN_WID_RAW)) 2>/dev/null; then
        continue
    fi

    if (( WIN_DEC == ACTIVE_WID_DEC )); then
        ACTIVE_MONITOR_ID="${!MONITOR_VAR:-}"
        ACTIVE_WIN_X="${!X_VAR:-0}"
        ACTIVE_WIN_Y="${!Y_VAR:-0}"
        ACTIVE_WIN_W="${!W_VAR:-0}"
        ACTIVE_WIN_H="${!H_VAR:-0}"
        log "INFO: Found active window in list: WID $(printf '0x%x' "$WIN_DEC") on monitor $ACTIVE_MONITOR_ID. Geometry: ${ACTIVE_WIN_X},${ACTIVE_WIN_Y},${ACTIVE_WIN_W}x${ACTIVE_WIN_H}"
        break
    fi
done

if [[ -z "$ACTIVE_MONITOR_ID" ]]; then
    log "WARNING: Active WID $ACTIVE_WID_CAN not found in 03_Window-List. Cannot proceed safely."
    printf "⚠️ AC07 SKIPPED: Active window not in window list. (Is it a sticky or minimized window?)\n"
    exit 0
fi

# ===== PARSE FLOATING WID LIST =====
FLOAT_WID_LIST=""
FLOAT_WID_ARRAY=()
NEW_FLOAT_WID_ARRAY=()
IS_FLOATING=false

clean_item() { printf '%s' "$1" | tr -d '\r' | xargs; }

if [[ -f "$FLOAT_DATA_FILE" ]]; then
    FLOAT_WID_LIST=$(grep '^FLOAT_WID_LIST=' "$FLOAT_DATA_FILE" | sed -n "s/FLOAT_WID_LIST='\(.*\)'/\1/p" || true)
fi

if [[ -n "$FLOAT_WID_LIST" ]]; then
    IFS=',' read -ra _parts <<< "$FLOAT_WID_LIST"
    for raw in "${_parts[@]}"; do
        part=$(clean_item "$raw")
        if [[ -z "$part" ]]; then
            continue
        fi

        if ! win_dec=$((part)) 2>/dev/null; then
            continue
        fi
        win_can=$(printf '0x%x' "$win_dec")
        FLOAT_WID_ARRAY+=("$win_can")

        if (( win_dec == ACTIVE_WID_DEC )); then
            IS_FLOATING=true
        fi
    done
fi

for win_can in "${FLOAT_WID_ARRAY[@]}"; do
    win_dec=$((win_can))
    if (( win_dec == ACTIVE_WID_DEC )); then
        continue
    fi
    NEW_FLOAT_WID_ARRAY+=("$win_can")
done

if $IS_FLOATING; then
    NEW_FLOAT_WID_LIST="$(printf '%s,' "${NEW_FLOAT_WID_ARRAY[@]}" | sed 's/,$//')"
else
    NEW_FLOAT_WID_LIST="$(printf '%s,' "${FLOAT_WID_ARRAY[@]}" | sed 's/,$//')"
fi

# ===== SYNC WITH LAST-VALID-STATE IF NEEDED =====
if [[ -f "$LAST_STATE_FILE" ]]; then
    if grep -q "^# --- WINDOW ${ACTIVE_WID_CAN} ---" "$LAST_STATE_FILE" 2>/dev/null; then
        if ! $IS_FLOATING; then
            log "WARNING: last-valid-state contains block for $ACTIVE_WID_CAN but FLOAT list did not. Forcing restore to avoid stale state."
            IS_FLOATING=true
            tmp_array=()
            for w in "${FLOAT_WID_ARRAY[@]}"; do
                if [[ "$w" != "$ACTIVE_WID_CAN" ]]; then
                    tmp_array+=("$w")
                fi
            done
            NEW_FLOAT_WID_LIST="$(printf '%s,' "${tmp_array[@]}" | sed 's/,$//')"
        fi
    fi
fi

# ===== TOGGLE FLOAT STATUS =====
if $IS_FLOATING; then
    log "ACTION: Transitioning $ACTIVE_WID_CAN from FLOATING to TILED (restoring geometry)."

    wmctrl -i -r "$ACTIVE_WID_CAN" -b 'remove,_NET_WM_STATE_DEMANDS_ATTENTION' || true
    wmctrl -i -r "$ACTIVE_WID_CAN" -b 'remove,above' || true

    RESTORE_GEOMETRY_FOUND=false
    RESTORE_X=0
    RESTORE_Y=0
    RESTORE_W=0
    RESTORE_H=0

    if [[ -f "$LAST_STATE_FILE" ]]; then
        X_LINE=$(grep "^WID_${ACTIVE_WID_CAN}_X=" "$LAST_STATE_FILE" || true)
        Y_LINE=$(grep "^WID_${ACTIVE_WID_CAN}_Y=" "$LAST_STATE_FILE" || true)
        W_LINE=$(grep "^WID_${ACTIVE_WID_CAN}_W=" "$LAST_STATE_FILE" || true)
        H_LINE=$(grep "^WID_${ACTIVE_WID_CAN}_H=" "$LAST_STATE_FILE" || true)

        if [[ -n "$X_LINE" && -n "$Y_LINE" && -n "$W_LINE" && -n "$H_LINE" ]]; then
            eval "$X_LINE"
            eval "$Y_LINE"
            eval "$W_LINE"
            eval "$H_LINE"

            var_x="WID_${ACTIVE_WID_CAN}_X"
            var_y="WID_${ACTIVE_WID_CAN}_Y"
            var_w="WID_${ACTIVE_WID_CAN}_W"
            var_h="WID_${ACTIVE_WID_CAN}_H"

            RESTORE_X="${!var_x:-}"
            RESTORE_Y="${!var_y:-}"
            RESTORE_W="${!var_w:-}"
            RESTORE_H="${!var_h:-}"

            if [[ -n "$RESTORE_W" && -n "$RESTORE_H" ]]; then
                RESTORE_GEOMETRY_FOUND=true
                log "INFO: Found saved geometry: $RESTORE_X,$RESTORE_Y,${RESTORE_W}x${RESTORE_H}."
            fi
        fi
    fi

    if $RESTORE_GEOMETRY_FOUND; then
        wmctrl -i -r "$ACTIVE_WID_CAN" -e 0,"$RESTORE_X","$RESTORE_Y","$RESTORE_W","$RESTORE_H" || true

        if [[ -f "$LAST_STATE_FILE" ]]; then
            awk -v hdr="^# --- WINDOW ${ACTIVE_WID_CAN} ---" 'BEGIN{RS=""; ORS=RS} $0 !~ hdr {print $0}' "$LAST_STATE_FILE" > "${LAST_STATE_FILE}.tmp" || true
            mv -f "${LAST_STATE_FILE}.tmp" "$LAST_STATE_FILE" || true
            log "INFO: Removed all saved state blocks for $ACTIVE_WID_CAN from $LAST_STATE_FILE."
        fi

        printf "✅ AC07 SUCCESS: Window %s is now Tiled (restored).\n" "$ACTIVE_WID_CAN"
        log "SUCCESS: Restored geometry for $ACTIVE_WID_CAN."
    else
        log "WARNING: No saved geometry found. Falling back to AC01_Tile-Vertical.sh."
        if "$ROOT_DIR/Actions/AC01_Tile-Vertical.sh"; then
            printf "⚠️ AC07 WARNING: Window %s is now Tiled (no saved state, layout reapplied).\n" "$ACTIVE_WID_CAN"
            log "WARNING: Applied fallback tiling for $ACTIVE_WID_CAN."
        else
            printf "❌ AC07 FAILED: Window %s tiling reapplication failed.\n" "$ACTIVE_WID_CAN"
            log "ERROR: Fallback tiling failed for $ACTIVE_WID_CAN."
        fi
    fi

    if [[ -n "$NEW_FLOAT_WID_LIST" ]]; then
        FLOAT_WID_COUNT=$(echo "$NEW_FLOAT_WID_LIST" | tr ',' '\n' | wc -l)
    else
        FLOAT_WID_COUNT=0
    fi

    mkdir -p "$(dirname "$FLOAT_DATA_FILE")"
    printf "FLOAT_WID_COUNT=%s\n" "$FLOAT_WID_COUNT" > "$FLOAT_DATA_FILE"
    printf "FLOAT_WID_LIST='%s'\n" "$NEW_FLOAT_WID_LIST" >> "$FLOAT_DATA_FILE"

else
    log "ACTION: Transitioning $ACTIVE_WID_CAN from TILED to FLOATING."

    mkdir -p "$LAST_STATE_DIR"
    if [[ -f "$LAST_STATE_FILE" ]]; then
        awk -v hdr="^# --- WINDOW ${ACTIVE_WID_CAN} ---" 'BEGIN{RS=""; ORS=RS} $0 !~ hdr {print $0}' "$LAST_STATE_FILE" > "${LAST_STATE_FILE}.tmp" || true
        mv -f "${LAST_STATE_FILE}.tmp" "$LAST_STATE_FILE" || true
    fi

    {
        printf "# --- WINDOW %s ---\n" "$ACTIVE_WID_CAN"
        printf "WID_%s_X=%s\n" "$ACTIVE_WID_CAN" "$ACTIVE_WIN_X"
        printf "WID_%s_Y=%s\n" "$ACTIVE_WID_CAN" "$ACTIVE_WIN_Y"
        printf "WID_%s_W=%s\n" "$ACTIVE_WID_CAN" "$ACTIVE_WIN_W"
        printf "WID_%s_H=%s\n" "$ACTIVE_WID_CAN" "$ACTIVE_WIN_H"
    } >> "$LAST_STATE_FILE"

    log "INFO: Saved structured geometry block for $ACTIVE_WID_CAN to $LAST_STATE_FILE."

    if [[ -n "$NEW_FLOAT_WID_LIST" ]]; then
        NEW_FLOAT_WID_LIST="${NEW_FLOAT_WID_LIST},${ACTIVE_WID_CAN}"
    else
        NEW_FLOAT_WID_LIST="${ACTIVE_WID_CAN}"
    fi
    NEW_FLOAT_WID_LIST=$(echo "$NEW_FLOAT_WID_LIST" | sed 's/^,*//;s/,*$//')

    FLOAT_WID_COUNT=$(echo "$NEW_FLOAT_WID_LIST" | tr ',' '\n' | wc -l)

    mkdir -p "$(dirname "$FLOAT_DATA_FILE")"
    printf "FLOAT_WID_COUNT=%s\n" "$FLOAT_WID_COUNT" > "$FLOAT_DATA_FILE"
    printf "FLOAT_WID_LIST='%s'\n" "$NEW_FLOAT_WID_LIST" >> "$FLOAT_DATA_FILE"
    log "INFO: Updated $FLOAT_DATA_FILE with: $NEW_FLOAT_WID_LIST"

    X_AREA_VAR="USABLE_AREA_${ACTIVE_MONITOR_ID}_X"; X_AREA=${!X_AREA_VAR}
    Y_AREA_VAR="USABLE_AREA_${ACTIVE_MONITOR_ID}_Y"; Y_AREA=${!Y_AREA_VAR}
    W_AREA_VAR="USABLE_AREA_${ACTIVE_MONITOR_ID}_WIDTH"; W_AREA=${!W_AREA_VAR}
    H_AREA_VAR="USABLE_AREA_${ACTIVE_MONITOR_ID}_HEIGHT"; H_AREA=${!H_AREA_VAR}

    FLOAT_W=$((W_AREA * 8 / 10))
    FLOAT_H=$((H_AREA * 8 / 10))
    FLOAT_X=$((X_AREA + (W_AREA - FLOAT_W) / 2))
    FLOAT_Y=$((Y_AREA + (H_AREA - FLOAT_H) / 2))

    wmctrl -i -r "$ACTIVE_WID_CAN" -b 'remove,maximized_vert,maximized_horz,fullscreen' || true
    wmctrl -i -r "$ACTIVE_WID_CAN" -e 0,"$FLOAT_X","$FLOAT_Y","$FLOAT_W","$FLOAT_H" || true

    log "ACTION: Toggled $ACTIVE_WID_CAN to Floating at $FLOAT_X,$FLOAT_Y,${FLOAT_W}x${FLOAT_H} (not forced above)."
    printf "✅ AC07 SUCCESS: Window %s is now Floating and centered.\n" "$ACTIVE_WID_CAN"
fi