#!/bin/bash
# File: AC02_Tile-Horizontal.sh
# Description: v2.2 - Horizontal tiling with Min-Height, overlap handling and terminal grid fix.
# Notes:
# 1. Applies horizontal split (rows).
# 2. If window height < Min Height, applies overlap.
# 3. Specific fix: reduces xfce4-terminal size to prevent grid overflow.
# 4. Final result: writes a .last-valid-state organized by DESKTOP / MONITOR (no history — always overwrites AC02_Tile-Horizontal.last-valid-state).

set -euo pipefail
IFS=$'\n\t'

# ===== 1. INITIALIZATION & GLOBAL PATHS =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC02_Tile-Vertical.log"

LAST_STATE_DIR="${LAST_STATE_DIR:-$ROOT_DIR/Actions/Actions_Last-Valid-States}"
LAST_STATE_FILE="${LAST_STATE_FILE:-$LAST_STATE_DIR/AC02_Tile-Horizontal.last-valid-state}"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$LAST_STATE_DIR"

# ===== UTILITY FUNCTIONS =====
log() {
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date +'%Y-%m-%d %H:%M:%S') [AC02_Tile-Horizontal] - $1" >> "$LOG_FILE"
}

: > "$LOG_FILE"
log "INFO: Script started (v2.2 Terminal Fix)."

# ===== 2. LOAD CONFIGURATION =====
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    exit 1
fi

# ===== 3. UPDATE ENVIRONMENT DATA (RUN.SH) =====
log "INFO: Updating environment data via run.sh..."

if [[ -x "$ROOT_DIR/run.sh" ]]; then
    if ! "$ROOT_DIR/run.sh"; then
        log "ERROR: run.sh failed (exit code non-zero). Aborting tiling to prevent errors."
        echo "❌ AC02 FAILED: Data update failed."
        exit 1
    fi
    log "INFO: Environment data updated successfully."
else
    log "WARNING: run.sh not found or not executable at $ROOT_DIR/run.sh. Using existing data."
fi

# ===== 4. LOAD DATA FILES =====
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
    log "INFO: Loaded all required data modules (including Min-Height)."
else
    log "ERROR: Required data files not found. Exiting."
    echo "❌ AC02 FAILED: Missing data files."
    exit 1
fi

# ===== 4.1 BUILD WID MAPS (MIN_HEIGHT, CLASS & TITLE) =====
declare -A MAP_WID_MIN_HEIGHT
declare -A MAP_WID_CLASS
declare -A MAP_WID_TITLE

log "INFO: Building WID maps..."
for ((i=1; i<=WINDOW_COUNT; i++)); do
    VAR_WID="WINDOW_${i}_WID"
    VAR_MIN_H="WINDOW_${i}_MIN_HEIGHT"
    VAR_CLASS="WINDOW_${i}_CLASS"
    VAR_TITLE="WINDOW_${i}_TITLE"
    
    if [[ -n "${!VAR_WID:-}" ]]; then
        CURr_WID="${!VAR_WID}"
        
        if [[ -n "${!VAR_MIN_H:-}" ]]; then
            MAP_WID_MIN_HEIGHT["$CURr_WID"]="${!VAR_MIN_H}"
        fi
        
        if [[ -n "${!VAR_CLASS:-}" ]]; then
            MAP_WID_CLASS["$CURr_WID"]="${!VAR_CLASS}"
        fi

        if [[ -n "${!VAR_TITLE:-}" ]]; then
            t="${!VAR_TITLE//[$'\r\n']/ }"
            MAP_WID_TITLE["$CURr_WID"]="$t"
        fi
    fi
done

# ===== 5. PROCESS WINDOWS PER MONITOR =====
CURRENT_DESKTOP_ID="${ACTIVE_DESKTOP:-}"
if [ -z "${CURRENT_DESKTOP_ID}" ]; then
    log "ERROR: Active desktop not found."
    exit 1
fi

TOTAL_TILED_WINDOWS=0
TILEABLE_GROUPS=0

for ((m_id = 1; m_id <= MONITOR_COUNT; m_id++)); do
    
    KEY="D${CURRENT_DESKTOP_ID}_M${m_id}"
    WID_LIST_VAR="${KEY}_CYCLE_LIST"
    WID_LIST="${!WID_LIST_VAR:-}"

    if [ -z "$WID_LIST" ]; then continue; fi

    OLD_IFS=$IFS
    IFS=' ' read -ra WIDS_ARRAY <<< "$WID_LIST"
    IFS=$OLD_IFS
    
    NUM_WINDOWS="${#WIDS_ARRAY[@]}"
    if [ "$NUM_WINDOWS" -eq 0 ]; then continue; fi
    
    TILEABLE_GROUPS=$((TILEABLE_GROUPS + 1))
    TOTAL_TILED_WINDOWS=$((TOTAL_TILED_WINDOWS + NUM_WINDOWS))
    
    X_AREA_VAR="USABLE_AREA_${m_id}_X"; X_AREA=${!X_AREA_VAR}
    Y_AREA_VAR="USABLE_AREA_${m_id}_Y"; Y_AREA=${!Y_AREA_VAR}
    W_AREA_VAR="USABLE_AREA_${m_id}_WIDTH"; W_AREA=${!W_AREA_VAR}
    H_AREA_VAR="USABLE_AREA_${m_id}_HEIGHT"; H_AREA=${!H_AREA_VAR}

    # ===== LOGIC: DETERMINE CONSTRAINTS (MAX MIN HEIGHT) =====
    GROUP_MAX_MIN_HEIGHT=0
    
    for wid in "${WIDS_ARRAY[@]}"; do
        MW="${MAP_WID_MIN_HEIGHT[$wid]:-100}"
        if [ "$MW" -gt "$GROUP_MAX_MIN_HEIGHT" ]; then
            GROUP_MAX_MIN_HEIGHT=$MW
        fi
    done
    
    log "MONITOR $m_id: $NUM_WINDOWS windows. Max Min-Height required: $GROUP_MAX_MIN_HEIGHT px."
    
    # ===== CASE 1: SINGLE WINDOW =====
    if [ "$NUM_WINDOWS" -eq 1 ]; then
        log "MONITOR $m_id: Applying full area geometry to single window."
        
        WID="${WIDS_ARRAY[0]}"
        wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen'
        
        GAPED_X=$((X_AREA + GAP_SIZE_PX))
        GAPED_Y=$((Y_AREA + GAP_SIZE_PX))
        GAPED_W=$((W_AREA - 2 * GAP_SIZE_PX))
        GAPED_H=$((H_AREA - 2 * GAP_SIZE_PX))
        
        # ===== TERMINAL FIX =====
        CLASS="${MAP_WID_CLASS[$WID]:-unknown}"
        if [[ "$CLASS" == "xfce4-terminal" ]]; then
            GAPED_W=$((GAPED_W - 16))
            GAPED_H=$((GAPED_H - 32))
        fi
        
        wmctrl -i -r "$WID" -e 0,"$GAPED_X","$GAPED_Y","$GAPED_W","$GAPED_H"
    
    # ===== CASE 2: MULTIPLE WINDOWS =====
    else
        TOTAL_HEIGHT_NO_GAPS=$((H_AREA - (NUM_WINDOWS - 1) * GAP_SIZE_PX))
        STANDARD_TILE_HEIGHT=$((TOTAL_HEIGHT_NO_GAPS / NUM_WINDOWS))
        
        if [ "$STANDARD_TILE_HEIGHT" -lt "$GROUP_MAX_MIN_HEIGHT" ]; then
            MODE="OVERLAP"
        else
            MODE="TILED"
        fi

        log "  -> Mode: $MODE (Std Height: $STANDARD_TILE_HEIGHT vs Req: $GROUP_MAX_MIN_HEIGHT)"

        if [ "$MODE" == "TILED" ]; then
            REMAINDER_HEIGHT=$((TOTAL_HEIGHT_NO_GAPS % NUM_WINDOWS))
            CURRENT_Y=$Y_AREA
            
            for ((idx = 0; idx < NUM_WINDOWS; idx++)); do
                WID="${WIDS_ARRAY[idx]}"
                wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen'
                
                HEIGHT_TO_APPLY=$STANDARD_TILE_HEIGHT
                if [ "$idx" -lt "$REMAINDER_HEIGHT" ]; then HEIGHT_TO_APPLY=$((HEIGHT_TO_APPLY + 1)); fi

                WINDOW_X=$((X_AREA + GAP_SIZE_PX))
                WINDOW_Y=$((CURRENT_Y))
                WINDOW_W=$((W_AREA - 2 * GAP_SIZE_PX))
                WINDOW_H=$((HEIGHT_TO_APPLY))

                if [ "$idx" -eq 0 ]; then
                    WINDOW_Y=$((WINDOW_Y + GAP_SIZE_PX))
                    WINDOW_H=$((WINDOW_H - GAP_SIZE_PX))
                elif [ "$idx" -eq $((NUM_WINDOWS - 1)) ]; then
                    WINDOW_H=$((WINDOW_H - GAP_SIZE_PX))
                fi
                
                # ===== TERMINAL FIX =====
                CLASS="${MAP_WID_CLASS[$WID]:-unknown}"
                if [[ "$CLASS" == "xfce4-terminal" ]]; then
                    WINDOW_W=$((WINDOW_W - 16))
                    WINDOW_H=$((WINDOW_H - 32))
                fi
                
                wmctrl -i -r "$WID" -e 0,"$WINDOW_X","$WINDOW_Y","$WINDOW_W","$WINDOW_H"
                CURRENT_Y=$((CURRENT_Y + HEIGHT_TO_APPLY + GAP_SIZE_PX))
            done

        else
            # ===== OVERLAP MODE (VERTICAL DECK) =====
            
            WINDOW_W=$((W_AREA - 2 * GAP_SIZE_PX))
            TARGET_H=$GROUP_MAX_MIN_HEIGHT
            SAFE_MAX_H=$((H_AREA - 2 * GAP_SIZE_PX))
            
            if [ "$TARGET_H" -gt "$SAFE_MAX_H" ]; then TARGET_H=$SAFE_MAX_H; fi

            SLACK_SPACE=$(( SAFE_MAX_H - TARGET_H ))
            if [ "$SLACK_SPACE" -lt 0 ]; then SLACK_SPACE=0; fi
            
            if [ "$NUM_WINDOWS" -gt 1 ]; then
                STEP_PX=$(( SLACK_SPACE / (NUM_WINDOWS - 1) ))
            else
                STEP_PX=0
            fi
            
            CURRENT_Y=$((Y_AREA + GAP_SIZE_PX))
            
            for ((idx = 0; idx < NUM_WINDOWS; idx++)); do
                WID="${WIDS_ARRAY[idx]}"
                wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen'
                
                WINDOW_X=$((X_AREA + GAP_SIZE_PX))
                WINDOW_Y=$CURRENT_Y
                WINDOW_H=$TARGET_H
                
                if [ "$idx" -eq $((NUM_WINDOWS - 1)) ]; then
                    WINDOW_Y=$(( (Y_AREA + H_AREA) - TARGET_H - GAP_SIZE_PX ))
                fi

                # ===== TERMINAL FIX =====
                CLASS="${MAP_WID_CLASS[$WID]:-unknown}"
                if [[ "$CLASS" == "xfce4-terminal" ]]; then
                    WINDOW_W=$((WINDOW_W - 2))
                    WINDOW_H=$((WINDOW_H - 32))
                fi

                wmctrl -i -r "$WID" -e 0,"$WINDOW_X","$WINDOW_Y","$WINDOW_W","$WINDOW_H"
                
                CURRENT_Y=$((CURRENT_Y + STEP_PX))
            done
        fi
    fi
done

# ===== 6. FINAL CLEANUP =====
if [ "$TOTAL_TILED_WINDOWS" -gt 0 ]; then
    echo "✅ AC02: Tiled $TOTAL_TILED_WINDOWS window(s) (Terminal Fix Applied)."
else
    echo "⚠️ AC02: No windows to tile."
fi

# ===== SAVE ORGANIZED LAST VALID STATE (AC02) =====
_payload="$(mktemp "${LAST_STATE_DIR}/AC02_payload.XXXXXX")"

{
    DESK_ID="${ACTIVE_DESKTOP:-}"
    if [[ -z "$DESK_ID" ]]; then DESK_ID=0; fi
    DESK_NAME_VAR="DESKTOP_${DESK_ID}_NAME"
    DESK_NAME="${!DESK_NAME_VAR:-}"
    printf "=== DESKTOP %s (%s) ===\n" "$DESK_ID" "$DESK_NAME"

    for MON_ID in $(seq 1 "${MONITOR_COUNT}"); do
        MON_NAME_VAR="MONITOR_${MON_ID}_NAME"
        MON_NAME="${!MON_NAME_VAR:-}"
        printf "\n--- MONITOR %s (%s) ---\n" "$MON_ID" "$MON_NAME"

        VAR="D${DESK_ID}_M${MON_ID}_CYCLE_LIST"
        WID_LIST="${!VAR:-}"

        if [[ -z "$WID_LIST" ]]; then
            printf "# Window Names: \n"
            printf "# Windows WIDs:\n\n"
            continue
        fi

        TITLES=""
        WIDS_LINE=""
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

} > "$_payload"

mv -f "$_payload" "$LAST_STATE_FILE"
chmod 0644 "$LAST_STATE_FILE" 2>/dev/null || true

echo "✅ Last-state written: $LAST_STATE_FILE"