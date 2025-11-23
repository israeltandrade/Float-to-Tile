#!/usr/bin/env bash
# File: AC05_Matrix-AutoTile.sh (v2.4+laststate - Min-Size, Overlap & Terminal Fix + last-state)
# Description: Applies a dynamic 3D Fibonacci/Spiral layout based on M07 and stores last valid state.

set -euo pipefail
IFS=$'\n\t'

# ===== CLI / DIAGNOSTIC MODE =====
DIAG=0
if [[ "${1:-}" == "--diag" ]]; then DIAG=1; fi
if [[ "${DIAG_OVERRIDE:-0}" == "1" ]]; then DIAG=1; fi

# ===== PATHS =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC05_Matrix-AutoTile.log"
MATRIX_FILE="$DATA_DIR/07_Layout-Matrices.data"
LAST_STATE_DIR="$ROOT_DIR/Actions/Actions_Last-Valid-States"
LAST_STATE_FILE="$LAST_STATE_DIR/AC05_Matrix-AutoTile.last-valid-state"

if ! mkdir -p "$(dirname "$LOG_FILE")"; then
    echo "ERROR: cannot create log directory: $(dirname "$LOG_FILE")" >&2
    exit 1
fi

if ! mkdir -p "$LAST_STATE_DIR"; then
    echo "ERROR: cannot create last-state directory: $LAST_STATE_DIR" >&2
    exit 1
fi

: > "$LOG_FILE"

safe_write() {
    local _file=$1; shift
    local _txt="$*"
    mkdir -p "$(dirname "$_file")"
    printf '%s\n' "$_txt" >> "$_file"
}

safe_write_no_nl() {
    local _file=$1; shift
    local _txt="$*"
    mkdir -p "$(dirname "$_file")"
    printf '%s' "$_txt" >> "$_file"
}

log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [AC05_Matrix-AutoTile] - $1" >> "$LOG_FILE"
    if [ "${DIAG:-0}" -eq 1 ]; then echo "[DIAG] $1"; fi
}

trim() { printf "%s" "$1" | tr -d '\r' | xargs; }

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

    if [[ -z "$widlist" ]] && compgen -v | grep -q "^D${D}_M${M}_MATRIX_3D_"; then
        for var in $(compgen -v | grep "^D${D}_M${M}_MATRIX_3D_" | sort); do
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

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    GAPS="${GAP_SIZE_PX:-10}"
    MASTER_RATIO="${MASTER_RATIO:-0.50}"
else
    GAPS=10
    MASTER_RATIO=0.50
fi

if [[ -x "$ROOT_DIR/run.sh" ]]; then
    if ! "$ROOT_DIR/run.sh"; then exit 1; fi
else
    if ! "$ROOT_DIR/run.sh" 2>/dev/null || true; then :; fi
fi

if [[ -f "$DATA_DIR/07_Layout-Matrices.data" ]]; then
    source "$DATA_DIR/01_Screen-Resolution.data"
    source "$DATA_DIR/02_Desktop-Details.data"
    source "$DATA_DIR/03_Window-List.data"
    source "$DATA_DIR/04_Monitor-Area.data"
    source "$DATA_DIR/06_Window-Cycle-Map.data"
    source "$DATA_DIR/07_Layout-Matrices.data"
else
    source "$DATA_DIR/01_Screen-Resolution.data"
    source "$DATA_DIR/02_Desktop-Details.data"
    source "$DATA_DIR/03_Window-List.data"
    source "$DATA_DIR/04_Monitor-Area.data"
    source "$DATA_DIR/06_Window-Cycle-Map.data"
fi

declare -A MAP_MIN_W
declare -A MAP_MIN_H
declare -A MAP_CLASS
declare -A MAP_TITLE

for ((i=1; i<=WINDOW_COUNT; i++)); do
    VAR_WID="WINDOW_${i}_WID"
    VAR_MW="WINDOW_${i}_MIN_WIDTH"
    VAR_MH="WINDOW_${i}_MIN_HEIGHT"
    VAR_CLS="WINDOW_${i}_CLASS"
    VAR_TITLE="WINDOW_${i}_TITLE"

    if [[ -n "${!VAR_WID:-}" ]]; then
        WID="${!VAR_WID}"
        MAP_MIN_W["$WID"]="${!VAR_MW:-100}"
        MAP_MIN_H["$WID"]="${!VAR_MH:-100}"
        MAP_CLASS["$WID"]="${!VAR_CLS:-unknown}"
        t="${!VAR_TITLE:-unknown}"
        t="${t//[$'\r\n']/ }"
        MAP_TITLE["$WID"]="$t"
    fi
done

recursive_fibonacci() {
    local R_X="$1" R_Y="$2" R_W="$3" R_H="$4" R_GAP="$5" R_DIR="$6" R_ITER="$7"
    local LIMIT_X="$8" LIMIT_Y="$9"
    shift 9
    local R_WIDS=("$@")
    local R_COUNT=${#R_WIDS[@]}

    if [ "$R_COUNT" -eq 0 ]; then return; fi

    local CURRENT_WID="${R_WIDS[0]}"
    local REMAINING_WIDS=("${R_WIDS[@]:1}")

    local MIN_W=${MAP_MIN_W["$CURRENT_WID"]:-100}
    local MIN_H=${MAP_MIN_H["$CURRENT_WID"]:-100}
    local CLASS="${MAP_CLASS[$CURRENT_WID]:-unknown}"

    if [ "$R_COUNT" -eq 1 ]; then
        local FINAL_W=$((R_W))
        local FINAL_H=$((R_H))
        local FINAL_X=$((R_X))
        local FINAL_Y=$((R_Y))

        if [ "$FINAL_W" -lt "$MIN_W" ]; then FINAL_W=$MIN_W; fi
        if [ "$FINAL_H" -lt "$MIN_H" ]; then FINAL_H=$MIN_H; fi

        if [ $((FINAL_X + FINAL_W)) -gt "$LIMIT_X" ]; then FINAL_X=$((LIMIT_X - FINAL_W)); fi
        if [ $((FINAL_Y + FINAL_H)) -gt "$LIMIT_Y" ]; then FINAL_Y=$((LIMIT_Y - FINAL_H)); fi

        local VISUAL_W=$FINAL_W
        local VISUAL_H=$FINAL_H
        if [[ "$CLASS" == "xfce4-terminal" ]]; then
            VISUAL_W=$((VISUAL_W - 0))
            VISUAL_H=$((VISUAL_H - 32))
        fi

        echo "${CURRENT_WID}:${FINAL_X},${FINAL_Y},${VISUAL_W},${VISUAL_H}"
        return
    fi

    local SPLIT_PCT=50
    if [ "$R_ITER" -eq 0 ]; then
        SPLIT_PCT=$(awk -v r="$MASTER_RATIO" 'BEGIN{ printf "%d", r*100 }')
    fi

    if [ "$R_DIR" -eq 0 ]; then
        local AVAILABLE_W=$(( R_W - R_GAP ))
        local CALC_W=$(( AVAILABLE_W * SPLIT_PCT / 100 ))
        if [ "$CALC_W" -lt 1 ]; then CALC_W=100; fi

        local ACTUAL_W=$CALC_W
        if [ "$ACTUAL_W" -lt "$MIN_W" ]; then ACTUAL_W=$MIN_W; fi

        local ACTUAL_H=$R_H
        if [ "$ACTUAL_H" -lt "$MIN_H" ]; then ACTUAL_H=$MIN_H; fi

        local POS_X=$R_X
        local POS_Y=$R_Y
        if [ $((POS_X + ACTUAL_W)) -gt "$LIMIT_X" ]; then POS_X=$((LIMIT_X - ACTUAL_W)); fi
        if [ $((POS_Y + ACTUAL_H)) -gt "$LIMIT_Y" ]; then POS_Y=$((LIMIT_Y - ACTUAL_H)); fi

        local VISUAL_W=$ACTUAL_W
        local VISUAL_H=$ACTUAL_H
        if [[ "$CLASS" == "xfce4-terminal" ]]; then
            VISUAL_W=$((VISUAL_W - 16))
            VISUAL_H=$((VISUAL_H - 32))
        fi

        echo "${CURRENT_WID}:${POS_X},${POS_Y},${VISUAL_W},${VISUAL_H}"

        local NEXT_X=$(( R_X + CALC_W + R_GAP ))
        local REMAIN_W=$(( AVAILABLE_W - CALC_W ))

        recursive_fibonacci "$NEXT_X" "$R_Y" "$REMAIN_W" "$R_H" "$R_GAP" 1 $((R_ITER+1)) "$LIMIT_X" "$LIMIT_Y" "${REMAINING_WIDS[@]}"

    else
        local AVAILABLE_H=$(( R_H - R_GAP ))
        local CALC_H=$(( AVAILABLE_H * SPLIT_PCT / 100 ))
        if [ "$CALC_H" -lt 1 ]; then CALC_H=100; fi

        local ACTUAL_H=$CALC_H
        if [ "$ACTUAL_H" -lt "$MIN_H" ]; then ACTUAL_H=$MIN_H; fi

        local ACTUAL_W=$R_W
        if [ "$ACTUAL_W" -lt "$MIN_W" ]; then ACTUAL_W=$MIN_W; fi

        local POS_X=$R_X
        local POS_Y=$R_Y
        if [ $((POS_Y + ACTUAL_H)) -gt "$LIMIT_Y" ]; then POS_Y=$((LIMIT_Y - ACTUAL_H)); fi
        if [ $((POS_X + ACTUAL_W)) -gt "$LIMIT_X" ]; then POS_X=$((LIMIT_X - ACTUAL_W)); fi

        local VISUAL_W=$ACTUAL_W
        local VISUAL_H=$ACTUAL_H
        if [[ "$CLASS" == "xfce4-terminal" ]]; then
            VISUAL_W=$((VISUAL_W - 16))
            VISUAL_H=$((VISUAL_H - 32))
        fi

        echo "${CURRENT_WID}:${POS_X},${POS_Y},${VISUAL_W},${VISUAL_H}"

        local NEXT_Y=$(( R_Y + CALC_H + R_GAP ))
        local REMAIN_H=$(( AVAILABLE_H - CALC_H ))

        recursive_fibonacci "$R_X" "$NEXT_Y" "$R_W" "$REMAIN_H" "$R_GAP" 0 $((R_ITER+1)) "$LIMIT_X" "$LIMIT_Y" "${REMAINING_WIDS[@]}"
    fi
}

calculate_3D_geometry() {
    local M_X="$1" M_Y="$2" M_W="$3" M_H="$4" GAPS="$5"
    shift 5
    local WIDS=("$@")

    local OUTER_GAP=$GAPS

    local USABLE_W=$(( M_W - (OUTER_GAP * 2) ))
    local USABLE_H=$(( M_H - (OUTER_GAP * 2) ))
    local X_START=$(( M_X + OUTER_GAP ))
    local Y_START=$(( M_Y + OUTER_GAP ))

    local LIMIT_X=$(( X_START + USABLE_W ))
    local LIMIT_Y=$(( Y_START + USABLE_H ))

    recursive_fibonacci "$X_START" "$Y_START" "$USABLE_W" "$USABLE_H" "$GAPS" 0 0 "$LIMIT_X" "$LIMIT_Y" "${WIDS[@]}"
}

# ===== MAIN LOOP =====
CURRENT_DESKTOP_ID="${ACTIVE_DESKTOP:-}"
if [ -z "$CURRENT_DESKTOP_ID" ]; then
    exit 1
fi

TOTAL_TILED_WINDOWS=0

for (( m_id=1; m_id<=MONITOR_COUNT; m_id++ )); do
    KEY="D${CURRENT_DESKTOP_ID}_M${m_id}"

    M_X_VAR="USABLE_AREA_${m_id}_X"; M_X="${!M_X_VAR:-}"
    M_Y_VAR="USABLE_AREA_${m_id}_Y"; M_Y="${!M_Y_VAR:-}"
    M_W_VAR="USABLE_AREA_${m_id}_WIDTH"; M_W="${!M_W_VAR:-}"
    M_H_VAR="USABLE_AREA_${m_id}_HEIGHT"; M_H="${!M_H_VAR:-}"

    if [ -z "${M_W:-}" ]; then continue; fi

    MATRIX_WIDS=()
    if [ -f "$MATRIX_FILE" ]; then
        while IFS= read -r line; do
            case "$line" in
                ${KEY}_MATRIX_3D_*=*)
                    val="${line#*=}"
                    val="$(trim "$val")"
                    if [ -n "$val" ]; then MATRIX_WIDS+=("$val"); fi
                    ;;
                *) ;;
            esac
        done < "$MATRIX_FILE"
    fi

    WIDS=()
    if [ "${#MATRIX_WIDS[@]}" -gt 0 ]; then
        WIDS=("${MATRIX_WIDS[@]}")
    else
        WID_LIST_VAR="${KEY}_CYCLE_LIST"
        WID_LIST="${!WID_LIST_VAR:-}"
        WID_LIST_CLEAN="$(printf '%s' "$WID_LIST" | tr -d "'" | awk '{$1=$1; print}')"
        OLD_IFS="$IFS"; IFS=' ' read -ra WIDS <<< "$WID_LIST_CLEAN"; IFS="$OLD_IFS"
        for i in "${!WIDS[@]}"; do WIDS[$i]="$(trim "${WIDS[$i]}")"; done
    fi

    COUNT=${#WIDS[@]}
    if [ "$COUNT" -eq 0 ]; then continue; fi

    GEOM_LIST="$(calculate_3D_geometry "$M_X" "$M_Y" "$M_W" "$M_H" "$GAPS" "${WIDS[@]}")"

    mapfile -t GEOM_ARR <<< "$GEOM_LIST"
    for ITEM in "${GEOM_ARR[@]}"; do
        ITEM="$(trim "$ITEM")"
        WID="${ITEM%%:*}"
        GEOM="${ITEM#*:}"
        WID="$(trim "$WID")"
        GEOM="$(trim "$GEOM")"

        if [ -z "$WID" ] || [ -z "$GEOM" ]; then continue; fi

        wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen' 2>/dev/null || true
        wmctrl -i -r "$WID" -e "0,$GEOM" || true
        TOTAL_TILED_WINDOWS=$((TOTAL_TILED_WINDOWS + 1))
    done
done

if [ "$TOTAL_TILED_WINDOWS" -gt 0 ]; then
    echo "✅ AC05: Tiled $TOTAL_TILED_WINDOWS windows (Terminal Fix Active)."
else
    echo "⚠️ AC05: No windows to tile."
fi

# ===== LAST VALID STATE WRITER =====
TMP_PAYLOAD="$(mktemp "${LAST_STATE_DIR}/AC05_payload.XXXXXX")" || exit 1

DESKTOP_NAME_VAR="DESKTOP_${CURRENT_DESKTOP_ID}_NAME"
DESKTOP_NAME="${!DESKTOP_NAME_VAR:-}"
safe_write "$TMP_PAYLOAD" "=== DESKTOP ${CURRENT_DESKTOP_ID} (${DESKTOP_NAME}) ==="
safe_write "$TMP_PAYLOAD" ""

for (( m_id=1; m_id<=MONITOR_COUNT; m_id++ )); do
    KEY="D${CURRENT_DESKTOP_ID}_M${m_id}"
    MON_NAME_VAR="MONITOR_${m_id}_NAME"
    MON_NAME="${!MON_NAME_VAR:-}"

    safe_write "$TMP_PAYLOAD" "--- MONITOR ${m_id} (${MON_NAME}) ---"

    WID_LIST="$(get_wid_list_for "$CURRENT_DESKTOP_ID" "$m_id")"

    TITLES=""; WIDS_LINE=""
    if [[ -n "$WID_LIST" ]]; then
        OLD_IFS="$IFS"; IFS=' ' read -ra WIDS_ARR <<< "$WID_LIST"; IFS="$OLD_IFS"
        for wid in "${WIDS_ARR[@]}"; do
            wid="$(trim "$wid")"
            if [[ -z "$wid" ]]; then continue; fi
            t="${MAP_TITLE[$wid]:-unknown}"
            if [[ -z "$TITLES" ]]; then
                TITLES="$t"
                WIDS_LINE="${wid}:"
            else
                TITLES="${TITLES} | ${t}"
                WIDS_LINE="${WIDS_LINE} ${wid}:"
            fi
        done
    fi

    if [[ -z "$TITLES" ]]; then
        safe_write "$TMP_PAYLOAD" "# Window Names:"
        safe_write "$TMP_PAYLOAD" "# Windows WIDs:"
        safe_write "$TMP_PAYLOAD" ""
        continue
    fi

    safe_write "$TMP_PAYLOAD" "# Window Names: ${TITLES}"
    safe_write "$TMP_PAYLOAD" "# Windows WIDs:"
    safe_write "$TMP_PAYLOAD" "$WIDS_LINE"
    safe_write "$TMP_PAYLOAD" ""
done

FINAL_TMP="$(mktemp "${LAST_STATE_DIR}/AC05_payload.final.XXXXXX")" || { rm -f "$TMP_PAYLOAD"; exit 1; }
mv -f "$TMP_PAYLOAD" "$FINAL_TMP"
mv -f "$FINAL_TMP" "$LAST_STATE_FILE"
chmod 0644 "$LAST_STATE_FILE" 2>/dev/null || true

# ===== FINAL LOG & CONFIRMATION =====
log "INFO: Last valid state written to $LAST_STATE_FILE"
safe_write "$LOG_FILE" "INFO: Last valid state written to $LAST_STATE_FILE"
printf '✅ Last-state written: %s\n' "$LAST_STATE_FILE"