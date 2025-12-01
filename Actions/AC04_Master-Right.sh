#!/usr/bin/env bash
# File: AC04_Master-Right.sh
# Description: v2.0 -> v2.6 SafeWriter. Applies Master-Right (master on right) and Stack-Left (stack on left).
# Notes: Reapplies safety patterns: safe printf, safe indirect expansions, preference for 07_Layout-Matrices,
#        atomic last_state writes and wmctrl operation logs.

set -euo pipefail
IFS=$'\n\t'

# ===== INITIALIZATION & PATHS =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC04_Master-Right.log"
LAST_STATE_DIR="$ROOT_DIR/Actions/Actions_Last-Valid-States"
LAST_STATE_FILE="$LAST_STATE_DIR/AC04_Master-Right.last-valid-state"
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

# ===== SAFE WRITERS =====
safe_write() { local _file=$1; shift; local _txt="$*"; mkdir -p "$(dirname "$_file")"; printf '%s\n' "$_txt" >> "$_file"; }
safe_write_no_nl() { local _file=$1; shift; local _txt="$*"; mkdir -p "$(dirname "$_file")"; printf '%s' "$_txt" >> "$_file"; }

# ===== LOGGING =====
log() {
    local msg="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    printf '%s %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "[$(basename "$0" .sh)] - $msg" >> "$LOG_FILE"
}

: > "$LOG_FILE"
log "INFO: Script started (v2.6 SafeWriter - MasterRight)."

# ===== LOAD CONFIG =====
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log "ERROR: Configuration file missing at $CONFIG_FILE. Exiting."
    echo "❌ CONFIG MISSING"
    exit 1
fi

GAPS="${GAP_SIZE_PX:-10}"
MASTER_RATIO="${MASTER_RATIO:-0.50}"

# ===== RUN.SH UPDATE (OPTIONAL) =====
log "INFO: Running run.sh to refresh data..."
if [[ -x "$ROOT_DIR/run.sh" ]]; then
    if ! "$ROOT_DIR/run.sh"; then
        log "ERROR: run.sh failed. Aborting."
        echo "❌ run.sh failed"
        exit 1
    fi
else
    log "INFO: run.sh not executable/missing; continuing."
fi

# ===== CHECK REQUIRED DATA FILES =====
required=( "01_Screen-Resolution.data" "02_Desktop-Details.data" "03_Window-List.data" "04_Monitor-Area.data" "06_Window-Cycle-Map.data" "08_Normalize-Windows.data" )
for f in "${required[@]}"; do
    if [[ ! -f "$DATA_DIR/$f" ]]; then
        log "ERROR: Required $f missing in $DATA_DIR. Exiting."
        echo "❌ Data missing: $f"
        exit 1
    fi
done

# ===== SOURCE DATA FILES =====
source "$DATA_DIR/01_Screen-Resolution.data"
source "$DATA_DIR/02_Desktop-Details.data"
source "$DATA_DIR/03_Window-List.data"
source "$DATA_DIR/04_Monitor-Area.data"
source "$DATA_DIR/06_Window-Cycle-Map.data"
source "$DATA_DIR/08_Normalize-Windows.data"

if [[ -f "$DATA_DIR/07_Layout-Matrices.data" ]]; then
    source "$DATA_DIR/07_Layout-Matrices.data"
    log "INFO: Loaded 07_Layout-Matrices.data (preferred)."
else
    log "INFO: 07_Layout-Matrices.data not present; using 06 cycle map."
fi

# ===== FLOATING WIDS =====
FLOAT_WID_LIST=""
if [[ -f "$FLOAT_DATA_FILE" ]]; then
    FLOAT_WID_LIST=$(grep '^FLOAT_WID_LIST=' "$FLOAT_DATA_FILE" | sed -n "s/FLOAT_WID_LIST='\(.*\)'/\1/p" || true)
fi

# ===== BUILD METADATA MAPS =====
declare -A MAP_MIN_W MAP_MIN_H MAP_CLASS MAP_TITLE
log "INFO: Building WID metadata maps..."
for ((i=1; i<=${WINDOW_COUNT:-0}; i++)); do
    VAR_WID="WINDOW_${i}_WID"
    WID="${!VAR_WID:-}"
    if [[ -n "$WID" ]]; then
        VAR_MW="WINDOW_${i}_MIN_WIDTH"
        VAR_MH="WINDOW_${i}_MIN_HEIGHT"
        VAR_CLS="WINDOW_${i}_CLASS"
        VAR_TITLE="WINDOW_${i}_TITLE"

        ORIGINAL_MIN_W="${!VAR_MW:-100}"
        ORIGINAL_MIN_H="${!VAR_MH:-100}"
        CLASS_NAME="${!VAR_CLS:-unknown}"

        # Get overridden base values from 08_Normalize-Windows.data
        VAR_BASE_W_FROM_08="WID_${WID}_BASE_W"
        VAR_BASE_H_FROM_08="WID_${WID}_BASE_H"
        OVERRIDDEN_BASE_W="${!VAR_BASE_W_FROM_08:-}"
        OVERRIDDEN_BASE_H="${!VAR_BASE_H_FROM_08:-}"

        # Apply override for Firefox if its base values are set to 1
        if [[ "$CLASS_NAME" == "Navigator" || "$CLASS_NAME" == "firefox" ]]; then
            if [[ -n "$OVERRIDDEN_BASE_W" && "$OVERRIDDEN_BASE_W" -eq 1 ]]; then
                MAP_MIN_W["$WID"]=1
            else
                MAP_MIN_W["$WID"]="$ORIGINAL_MIN_W"
            fi
            if [[ -n "$OVERRIDDEN_BASE_H" && "$OVERRIDDEN_BASE_H" -eq 1 ]]; then
                MAP_MIN_H["$WID"]=1
            else
                MAP_MIN_H["$WID"]="$ORIGINAL_MIN_H"
            fi
        else
            MAP_MIN_W["$WID"]="$ORIGINAL_MIN_W"
            MAP_MIN_H["$WID"]="$ORIGINAL_MIN_H"
        fi

        MAP_CLASS["$WID"]="$CLASS_NAME"
        title="${!VAR_TITLE:-unknown}"
        title="${title//[$'\r\n']/ }"
        MAP_TITLE["$WID"]="$title"
    fi
done

# ===== ACTIVE DESKTOP & PAYLOAD PREP =====
ACTIVE_DESK="${ACTIVE_DESKTOP:-0}"
log "INFO: ACTIVE_DESKTOP=${ACTIVE_DESK}"

TOTAL_TILED=0
TMP_PAYLOAD="$(mktemp "${LAST_STATE_DIR}/AC04_payload.XXXXXX")" || { log "ERROR: mktemp failed"; exit 1; }

DESKTOP_NAME_VAR="DESKTOP_${ACTIVE_DESK}_NAME"
DESKTOP_NAME="${!DESKTOP_NAME_VAR:-}"
safe_write "$TMP_PAYLOAD" "=== DESKTOP ${ACTIVE_DESK} (${DESKTOP_NAME}) ==="
safe_write "$TMP_PAYLOAD" ""

# ===== WID LIST HELPER (PREFER MATRIX, FALLBACK TO CYCLE) =====
get_wid_list_for() {
    local D=$1 M=$2 widlist=""
    if compgen -v | grep -q "^D${D}_M${M}_MATRIX_2D_"; then
        for var in $(compgen -v | grep "^D${D}_M${M}_MATRIX_2D_" | sort); do
            val="${!var:-}"
            if [[ -n "$val" ]]; then
                if [[ -z "$widlist" ]]; then widlist="$val"; else widlist="$widlist $val"; fi
            fi
        done
    fi
    if [[ -z "$widlist" ]]; then
        local key="D${D}_M${M}_CYCLE_LIST"
        widlist="${!key:-}"
    fi
    printf '%s' "$widlist" | tr -d "'" | awk '{$1=$1; print}'
}

# ===== LOOP MONITORS ON ACTIVE DESKTOP =====
for ((m_id=1; m_id<=${MONITOR_COUNT:-0}; m_id++)); do
    WID_LIST="$(get_wid_list_for "$ACTIVE_DESK" "$m_id")"

    MON_NAME_VAR="MONITOR_${m_id}_NAME"
    MON_NAME="${!MON_NAME_VAR:-}"

    safe_write "$TMP_PAYLOAD" "--- MONITOR ${m_id} (${MON_NAME}) ---"

    if [[ -z "$WID_LIST" ]]; then
        safe_write "$TMP_PAYLOAD" "# Window Names:"
        safe_write "$TMP_PAYLOAD" "# Windows WIDs:"
        safe_write "$TMP_PAYLOAD" ""
        continue
    fi

    OLD_IFS=$IFS; IFS=' ' read -ra WIDS <<< "$WID_LIST"; IFS=$OLD_IFS
    COUNT=${#WIDS[@]}
    if [ "$COUNT" -eq 0 ]; then
        safe_write "$TMP_PAYLOAD" "# Window Names:"
        safe_write "$TMP_PAYLOAD" "# Windows WIDs:"
        safe_write "$TMP_PAYLOAD" ""
        continue
    fi

    TOTAL_TILED=$((TOTAL_TILED + COUNT))

    # ===== BUILD TITLES & WIDS LINES =====
    TITLES=""; WIDS_LINE=""
    for wid in "${WIDS[@]}"; do
        t="${MAP_TITLE[$wid]:-unknown}"
        if [[ -z "$TITLES" ]]; then
            TITLES="$t"
            WIDS_LINE="${wid}:"
        else
            TITLES="${TITLES} | ${t}"
            WIDS_LINE="${WIDS_LINE} ${wid}:"
        fi
    done
    safe_write "$TMP_PAYLOAD" "# Window Names: ${TITLES}"
    safe_write "$TMP_PAYLOAD" "# Windows WIDs:"
    safe_write "$TMP_PAYLOAD" "$WIDS_LINE"
    safe_write "$TMP_PAYLOAD" ""

    # ===== MONITOR AREAS (SAFE INDIRECT EXPANSIONS) =====
    X_AREA_VAR="USABLE_AREA_${m_id}_X"; X_AREA="${!X_AREA_VAR:-0}"
    Y_AREA_VAR="USABLE_AREA_${m_id}_Y"; Y_AREA="${!Y_AREA_VAR:-0}"
    W_AREA_VAR="USABLE_AREA_${m_id}_WIDTH"; W_AREA="${!W_AREA_VAR:-100}"
    H_AREA_VAR="USABLE_AREA_${m_id}_HEIGHT"; H_AREA="${!H_AREA_VAR:-100}"

    SAFE_X=$(( X_AREA + GAPS ))
    SAFE_Y=$(( Y_AREA + GAPS ))
    SAFE_W=$(( W_AREA - 2 * GAPS ))
    SAFE_H=$(( H_AREA - 2 * GAPS ))
    if [ "$SAFE_W" -le 0 ]; then SAFE_W=10; fi
    if [ "$SAFE_H" -le 0 ]; then SAFE_H=10; fi

    LIMIT_RIGHT=$(( SAFE_X + SAFE_W ))
    LIMIT_BOTTOM=$(( SAFE_Y + SAFE_H ))

    log "INFO: MONITOR $m_id - count=${COUNT} safe=${SAFE_W}x${SAFE_H} at ${SAFE_X},${SAFE_Y}"

    # ===== MASTER (FIRST) - ANCHORED RIGHT =====
    MASTER_WID="${WIDS[0]}"
    if [ "$COUNT" -eq 1 ]; then
        IDEAL_MASTER_W=$SAFE_W
    else
        IDEAL_MASTER_W=$(awk -v w="$SAFE_W" -v g="$GAPS" -v r="$MASTER_RATIO" 'BEGIN{printf "%d", (w - g) * r}')
    fi

    MIN_W="${MAP_MIN_W[$MASTER_WID]:-100}"
    ACTUAL_MASTER_W=$IDEAL_MASTER_W
    if [ "$ACTUAL_MASTER_W" -lt "$MIN_W" ]; then ACTUAL_MASTER_W=$MIN_W; fi
    if [ "$ACTUAL_MASTER_W" -gt "$SAFE_W" ]; then ACTUAL_MASTER_W=$SAFE_W; fi

    MASTER_X=$(( LIMIT_RIGHT - ACTUAL_MASTER_W ))

    TARGET_MASTER_W=$ACTUAL_MASTER_W
    TARGET_MASTER_H=$SAFE_H

    # ===== GRID-UNIT WINDOW ADJUSTMENT =====
    VAR_HAS_GRID="WID_${MASTER_WID}_HAS_GRID"
    if [[ "${!VAR_HAS_GRID:-}" == "1" ]]; then
        VAR_BASE_W="WID_${MASTER_WID}_BASE_W"
        VAR_BASE_H="WID_${MASTER_WID}_BASE_H"
        VAR_INC_W="WID_${MASTER_WID}_INC_W"
        VAR_INC_H="WID_${MASTER_WID}_INC_H"

        BASE_W=${!VAR_BASE_W:-0}
        BASE_H=${!VAR_BASE_H:-0}
        INC_W=${!VAR_INC_W:-1}
        INC_H=${!VAR_INC_H:-1}

        if [ "$INC_W" -eq 0 ]; then INC_W=1; fi
        if [ "$INC_H" -eq 0 ]; then INC_H=1; fi

        GRID_W=$(( (TARGET_MASTER_W - BASE_W) / INC_W ))
        GRID_H=$(( (TARGET_MASTER_H - BASE_H) / INC_H ))

        TARGET_MASTER_W=$(( BASE_W + GRID_W * INC_W ))
        TARGET_MASTER_H=$(( BASE_H + GRID_H * INC_H ))
    fi

    if [ "$TARGET_MASTER_W" -lt 10 ]; then TARGET_MASTER_W=10; fi
    if [ "$TARGET_MASTER_H" -lt 10 ]; then TARGET_MASTER_H=10; fi

    wmctrl -i -r "$MASTER_WID" -b 'remove,maximized_vert,maximized_horz,fullscreen' || true
    if wmctrl -i -r "$MASTER_WID" -e 0,"$MASTER_X","$SAFE_Y","$TARGET_MASTER_W","$TARGET_MASTER_H"; then
        log "INFO: Master $MASTER_WID applied ${TARGET_MASTER_W}x${TARGET_MASTER_H} at ${MASTER_X},${SAFE_Y}"
    else
        log "WARN: wmctrl falhou aplicando master $MASTER_WID"
    fi

    # ===== STACK (REMAINING) - ANCHORED LEFT =====
    if [ "$COUNT" -gt 1 ]; then
        STACK_START_X=$SAFE_X
        STACK_AVAIL_W=$(( MASTER_X - GAPS - SAFE_X ))
        if [ "$STACK_AVAIL_W" -lt 100 ]; then STACK_AVAIL_W=$(( SAFE_W - ACTUAL_MASTER_W )); fi

        NUM_STACK=$(( COUNT - 1 ))
        TOTAL_GAPS_H=$(( (NUM_STACK - 1) * GAPS ))
        STACK_AVAIL_H=$(( SAFE_H - TOTAL_GAPS_H ))
        if [ "$STACK_AVAIL_H" -le 0 ]; then STACK_AVAIL_H=$NUM_STACK; fi
        STD_STACK_H=$(( STACK_AVAIL_H / NUM_STACK ))
        REMAINDER_H=$(( STACK_AVAIL_H % NUM_STACK ))

        CURRENT_Y=$SAFE_Y

        for ((idx=1; idx<COUNT; idx++)); do
            WID="${WIDS[idx]}"
            BASE_H=$STD_STACK_H
            if [ $((idx-1)) -lt "$REMAINDER_H" ]; then BASE_H=$((BASE_H + 1)); fi

            MIN_W_STACK="${MAP_MIN_W[$WID]:-100}"
            MIN_H_STACK="${MAP_MIN_H[$WID]:-100}"

            ACTUAL_H=$BASE_H
            if [ "$ACTUAL_H" -lt "$MIN_H_STACK" ]; then ACTUAL_H=$MIN_H_STACK; fi

            ACTUAL_W=$STACK_AVAIL_W
            if [ "$ACTUAL_W" -lt "$MIN_W_STACK" ]; then ACTUAL_W=$MIN_W_STACK; fi

            POS_X=$STACK_START_X
            POS_Y=$CURRENT_Y

            if [ $(( POS_X + ACTUAL_W )) -gt "$LIMIT_RIGHT" ]; then
                ACTUAL_W=$(( LIMIT_RIGHT - POS_X ))
            fi

            if [ "$idx" -eq $((COUNT - 1)) ]; then
                if [ $(( POS_Y + ACTUAL_H )) -gt "$LIMIT_BOTTOM" ]; then
                    POS_Y=$(( LIMIT_BOTTOM - ACTUAL_H ))
                fi
            fi

            TARGET_STACK_W=$ACTUAL_W
            TARGET_STACK_H=$ACTUAL_H
            
            # ===== GRID-UNIT WINDOW ADJUSTMENT =====
            VAR_HAS_GRID="WID_${WID}_HAS_GRID"
            if [[ "${!VAR_HAS_GRID:-}" == "1" ]]; then
                VAR_BASE_W="WID_${WID}_BASE_W"
                VAR_BASE_H="WID_${WID}_BASE_H"
                VAR_INC_W="WID_${WID}_INC_W"
                VAR_INC_H="WID_${WID}_INC_H"

                BASE_W=${!VAR_BASE_W:-0}
                BASE_H=${!VAR_BASE_H:-0}
                INC_W=${!VAR_INC_W:-1}
                INC_H=${!VAR_INC_H:-1}

                if [ "$INC_W" -eq 0 ]; then INC_W=1; fi
                if [ "$INC_H" -eq 0 ]; then INC_H=1; fi

                GRID_W=$(( (TARGET_STACK_W - BASE_W) / INC_W ))
                GRID_H=$(( (TARGET_STACK_H - BASE_H) / INC_H ))

                TARGET_STACK_W=$(( BASE_W + GRID_W * INC_W ))
                TARGET_STACK_H=$(( BASE_H + GRID_H * INC_H ))
            fi

            if [ "$TARGET_STACK_H" -lt 10 ]; then TARGET_STACK_H=10; fi

            wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen' || true
            if wmctrl -i -r "$WID" -e 0,"$POS_X","$POS_Y","$TARGET_STACK_W","$TARGET_STACK_H"; then
                log "INFO: Stack $WID applied ${TARGET_STACK_W}x${TARGET_STACK_H} at ${POS_X},${POS_Y}"
            else
                log "WARN: wmctrl falhou aplicando stack $WID"
            fi

            CURRENT_Y=$(( CURRENT_Y + BASE_H + GAPS ))
        done
    fi
done

# ===== FEEDBACK =====
if [ "$TOTAL_TILED" -gt 0 ]; then
    printf '✅ AC04: Master-Right applied to %d window(s).\n' "$TOTAL_TILED"
else
    printf '⚠️ AC04: No windows found on active desktop.\n'
fi

# ===== ATOMIC LAST-STATE WRITE =====
FINAL_TMP="$(mktemp "${LAST_STATE_DIR}/AC04_payload.final.XXXXXX")" || { log "ERROR: mktemp final failed"; exit 1; }
mv -f "$TMP_PAYLOAD" "$FINAL_TMP"
mv -f "$FINAL_TMP" "$LAST_STATE_FILE"
chmod 0644 "$LAST_STATE_FILE" 2>/dev/null || true

log "INFO: Last valid state written to $LAST_STATE_FILE"
safe_write "$LOG_FILE" "INFO: Last valid state written to $LAST_STATE_FILE"
printf '✅ Last-state written: %s\n' "$LAST_STATE_FILE"
