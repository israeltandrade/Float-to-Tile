#!/usr/bin/env bash

# File: 03_Window-List.sh (v1.9.6 - Full Dump + IFS Fix)
# Description: Captures window data including min-size hints using full property dump. Fixes IFS splitting issue.
# Dependencies: wmctrl, awk, sort, xprop, ps, date, timeout, getconf. Depends on 01_Screen-Resolution.data and 02_Desktop-Details.data.

set -euo pipefail
IFS=$'\n\t'

# ===== PATH CONFIGURATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ===== DIRECTORY GUARANTEE =====
mkdir -p "$ROOT_DIR/Logs" \
         "$ROOT_DIR/Data" \
         "$ROOT_DIR/Last-Valid-States"

LOG_FILE="$ROOT_DIR/Logs/03_Window-List.log"
DATA_FILE="$ROOT_DIR/Data/03_Window-List.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/Last-Valid-States/03_Window-List.last-valid-state"

MONITOR_DATA_FILE="$ROOT_DIR/Data/01_Screen-Resolution.data"
DESKTOP_DATA_FILE="$ROOT_DIR/Data/02_Desktop-Details.data"

TEMP_WMCTRL_FILE="/tmp/wmctrl_list_$$"
TEMP_UNSORTED_FILE="/tmp/wmctrl_list_unsorted_$$"
TEMP_UNSORTED_FINAL="${TEMP_UNSORTED_FILE}.final"
TEMP_FINAL_DATA="/tmp/final_data_$$"

# ===== UTILITY FUNCTIONS =====
log() {
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# ===== MONITOR/DESKTOP DATA LOADING =====
read_monitor_data() {
    local m_idx
    MONITOR_COUNT=$(grep '^MONITOR_COUNT=' "$MONITOR_DATA_FILE" | cut -d'=' -f2)

    m_idx=1
    while [ "$m_idx" -le "$MONITOR_COUNT" ]; do
        MONITOR_X[$m_idx]=$(grep "MONITOR_${m_idx}_POS_X" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_Y[$m_idx]=$(grep "MONITOR_${m_idx}_POS_Y" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_W[$m_idx]=$(grep "MONITOR_${m_idx}_WIDTH" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_H[$m_idx]=$(grep "MONITOR_${m_idx}_HEIGHT" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        MONITOR_NAME[$m_idx]=$(grep "MONITOR_${m_idx}_NAME" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        m_idx=$((m_idx + 1))
    done
}

read_desktop_names() {
    local d_idx
    DESKTOP_COUNT=$(grep '^DESKTOP_COUNT=' "$DESKTOP_DATA_FILE" | cut -d'=' -f2)

    d_idx=0
    while [ "$d_idx" -lt "$DESKTOP_COUNT" ]; do
        DESKTOP_NAME[$d_idx]=$(grep "DESKTOP_${d_idx}_NAME=" "$DESKTOP_DATA_FILE" | cut -d'=' -f2 | tr -d \''"')
        d_idx=$((d_idx + 1))
    done
}

get_monitor_id() {
    local win_x=$1 win_y=$2 win_w=$3 win_h=$4
    local center_x=$((win_x + win_w / 2))
    local center_y=$((win_y + win_h / 2))
    local monitor_id=0
    local m_idx=1

    while [ "$m_idx" -le "$MONITOR_COUNT" ]; do
        local m_x=${MONITOR_X[$m_idx]} m_y=${MONITOR_Y[$m_idx]}
        local m_w=${MONITOR_W[$m_idx]} m_h=${MONITOR_H[$m_idx]}
        
        if [ "$center_x" -ge "$m_x" ] && [ "$center_x" -lt "$((m_x + m_w))" ] && \
           [ "$center_y" -ge "$m_y" ] && [ "$center_y" -lt "$((m_y + m_h))" ]; then
            monitor_id=$m_idx
            break
        fi
        m_idx=$((m_idx + 1))
    done
    
    echo "$monitor_id"
}

# ===== INITIALIZATION =====
: > "$LOG_FILE"
trap 'rm -f "$TEMP_WMCTRL_FILE" "$TEMP_UNSORTED_FILE" "$TEMP_UNSORTED_FINAL" "$TEMP_FINAL_DATA"' EXIT
log "MODULE 03 START (v1.9.6 - Full Dump + IFS Fix)"

# ===== DEPENDENCY CHECK & DATA LOAD =====
if [ ! -f "$MONITOR_DATA_FILE" ]; then
    log "FAILURE: Monitor data file $MONITOR_DATA_FILE not found."
    printf "❌ M03 FAILED: Monitor data file not found.\n"
    exit 1
fi
read_monitor_data

if [ ! -f "$DESKTOP_DATA_FILE" ]; then
    log "FAILURE: Desktop data file $DESKTOP_DATA_FILE not found."
    printf "❌ M03 FAILED: Desktop data file not found.\n"
    exit 1
fi
read_desktop_names

if [ -z "${MONITOR_COUNT:-}" ] || [ "$MONITOR_COUNT" -eq 0 ]; then
    log "FAILURE: Monitor count is zero or missing in data file."
    printf "❌ M03 FAILED: Monitor count is zero or missing.\n"
    exit 1
fi

# ===== WINDOW DATA ACQUISITION =====
log "EXECUTING WMCTRL -LXG"
if ! wmctrl -lxG > "$TEMP_WMCTRL_FILE"; then
    log "FAILURE: Command 'wmctrl -lxG' failed."
    printf "❌ M03 FAILED: wmctrl command failed. Please ensure wmctrl is installed.\n"
    exit 1
fi

# ===== AWK FILTERING AND BASE EXTRACTION =====
log "AWK: FILTERING WINDOWS"

awk -f - "$TEMP_WMCTRL_FILE" > "$TEMP_UNSORTED_FILE" <<'AWK'
! /xfce4-panel|xfdesktop/ && $2 != "-1" {
    split($7, class_res, ".")
    window_title = ""
    for (i = 9; i <= NF; i++) {
        if (window_title) window_title = window_title " " $i
        else window_title = $i
    }
    print $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" class_res[1] "|" class_res[2] "|" window_title
}
AWK

# ===== MONITOR DETECTION (BASH) AND FINAL FORMATTING/SORTING =====
log "BASH: STARTING DATA FETCH LOOP (USER_TIME, PID, PROCESS_START_TIME, HINTS)"

WINDOW_COUNT=0

: > "$TEMP_UNSORTED_FINAL"

while IFS='|' read -r WID DESKTOP POS_X POS_Y WIDTH HEIGHT CLASS RESOURCE TITLE; do
    
    log "LOOP START: Processing WID: $WID ($TITLE)"
    
    log "  -> Fetching USER_TIME..."
    USER_TIME_HEX=$(xprop -id "$WID" _NET_WM_USER_TIME 2>/dev/null | awk -F'= ' '/_NET_WM_USER_TIME/ {print $2; exit}')
    USER_TIME_DEC=0
    if [[ -n "$USER_TIME_HEX" && "$USER_TIME_HEX" != "not found." ]]; then
        CLEAN_HEX="${USER_TIME_HEX//0x/}"
        if [ -n "$CLEAN_HEX" ]; then
            USER_TIME_DEC=$((16#$CLEAN_HEX))
        fi
    fi
    log "      USER_TIME (DEC): $USER_TIME_DEC"

    log "  -> Fetching PID..."
    PID_RAW=$(xprop -id "$WID" _NET_WM_PID 2>/dev/null | awk -F'= ' '/_NET_WM_PID/ {print $2; exit}')
    PID=0
    if [[ -n "$PID_RAW" && "$PID_RAW" != "not found." ]]; then
        PID_RAW="$(echo "$PID_RAW" | tr -d '[:space:]')"
        if [[ "$PID_RAW" =~ ^0x ]]; then
            PID=$((16#${PID_RAW#0x}))
        elif [[ "$PID_RAW" =~ ^[0-9]+$ ]]; then
            PID=$((10#$PID_RAW))
        else
            PID_DIGITS=$(echo "$PID_RAW" | sed 's/[^0-9]*//g')
            if [[ -n "$PID_DIGITS" ]]; then
                PID=$((10#$PID_DIGITS))
            fi
        fi
    fi
    log "      PID (DEC): $PID"

    P_START_TIME_DEC=0
    if [ "$PID" -gt 0 ]; then
        log "  -> Attempting to fetch PROCESS START TIME for PID $PID (strategies: etimes -> lstart -> /proc)..."

        ETIMES_STR=$(timeout 1s ps -p "$PID" -o etimes= 2>/dev/null || echo "")
        ETIMES_STR="$(echo "$ETIMES_STR" | tr -d '[:space:]')"
        if [[ -n "$ETIMES_STR" && "$ETIMES_STR" =~ ^[0-9]+$ ]]; then
            now_epoch=$(date +%s)
            P_START_TIME_DEC=$(( now_epoch - ETIMES_STR ))
            log "      Strategy etimes succeeded: etimes=$ETIMES_STR -> start_epoch=$P_START_TIME_DEC"
        else
            LSTART_STR=$(timeout 1s ps -p "$PID" -o lstart= 2>/dev/null || echo "")
            LSTART_STR="$(echo "$LSTART_STR" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            if [ -n "$LSTART_STR" ]; then
                P_START_TIME_DEC=$(date -d "$LSTART_STR" +%s 2>/dev/null || echo 0)
                if [ "$P_START_TIME_DEC" -gt 0 ]; then
                    log "      Strategy lstart succeeded: '$LSTART_STR' -> start_epoch=$P_START_TIME_DEC"
                else
                    log "      Strategy lstart failed to convert '$LSTART_STR' with date -d."
                    P_START_TIME_DEC=0
                fi
            fi

            if [ "$P_START_TIME_DEC" -eq 0 ] && [ -r "/proc/$PID/stat" ]; then
                stat_field=$(awk '{print $22}' "/proc/$PID/stat" 2>/dev/null || echo "")
                if [[ "$stat_field" =~ ^[0-9]+$ ]]; then
                    clk_tck=$(getconf CLK_TCK 2>/dev/null || echo 100)
                    uptime_seconds=$(awk '{print $1}' /proc/uptime 2>/dev/null || echo 0)
                    now_epoch=$(date +%s)
                    boot_epoch=$(( now_epoch - ${uptime_seconds%.*} ))
                    start_secs_since_boot=$(( stat_field / clk_tck ))
                    P_START_TIME_DEC=$(( boot_epoch + start_secs_since_boot ))
                    log "      Strategy /proc succeeded: stat_start=${stat_field}, clk_tck=${clk_tck}, start_epoch=${P_START_TIME_DEC}"
                else
                    log "      /proc stat field absent or unparsable for PID $PID."
                fi
            fi
        fi

        if [ "$P_START_TIME_DEC" -eq 0 ]; then
            log "      All strategies failed to determine PROCESS_START_TIME for PID $PID."
        else
            log "      PROCESS_START_TIME (Epoch): $P_START_TIME_DEC"
        fi
    else
        log "      Skipping start-time fetch: PID not available."
    fi
    
    # ===== ROBUST WM_NORMAL_HINTS BLOCK START (v1.9.6 - Full Dump + IFS Safe Read) =====
    log "  -> [DEBUG] Fetching Hints for WID: $WID"
    MIN_W=0
    MIN_H=0
    
    FULL_XPROP=$(timeout 1s xprop -id "$WID" 2>/dev/null || echo "")
    
    if [ -n "$FULL_XPROP" ]; then
        HINT_LINE=$(echo "$FULL_XPROP" | grep "program specified minimum size" || true)
        
        if [ -n "$HINT_LINE" ]; then
            log "      [DEBUG-RAW] Line found: $HINT_LINE"
            
            VALS=$(echo "$HINT_LINE" | awk '{for(i=1;i<=NF;i++) if($i=="by") print $(i-1)" "$(i+1)}')
            
            if [ -n "$VALS" ]; then
                IFS=' ' read -r MIN_W MIN_H <<< "$VALS"
            fi
        fi
    else
        log "      [DEBUG-FAIL] xprop returned empty."
    fi

    [[ "$MIN_W" =~ ^[0-9]+$ ]] || MIN_W=0
    [[ "$MIN_H" =~ ^[0-9]+$ ]] || MIN_H=0
    
    log "      [RESULT] MIN SIZE: ${MIN_W}x${MIN_H}"
    # ===== ROBUST WM_NORMAL_HINTS BLOCK END =====

    log "  -> Detecting Monitor..."
    MONITOR_ID=$(get_monitor_id "$POS_X" "$POS_Y" "$WIDTH" "$HEIGHT")
    
    if [ "$MONITOR_ID" -eq 0 ]; then
        log "WARNING: WINDOW $WID CENTER POINT NOT FOUND ON ANY MONITOR. SKIPPING."
        continue
    fi
    log "      Monitor ID: $MONITOR_ID"
    
    WINDOW_COUNT=$((WINDOW_COUNT + 1))
    
    CLASS_Q=$(printf "%q" "$CLASS")
    RESOURCE_Q=$(printf "%q" "$RESOURCE")
    
    CANDIDATE="$(printf '%s' "$TITLE" | awk '{
        IGNORE_RE = "youtube|microsoft team|microsoft teams|teams|firefox|chrome|chromium|vivaldi|slack|telegram|whatsapp|discord|gmail|outlook|skype|zoom|vscode|obs";
        s = $0;
        gsub(/ - | — |: | · /, "\034", s);
        gsub(/\|/, "\034", s);
        n = split(s, a, "\034");
        for(i=1;i<=n;i++){
            g = a[i];
            sub(/^[ \t]+/, "", g); sub(/[ \t]+$/, "", g);
            a[i]=g;
        }
        best_provider = "";
        for(i=1;i<=n;i++){
            low = tolower(a[i]);
            if(low ~ IGNORE_RE){
                if(length(a[i]) > length(best_provider)) best_provider = a[i];
            }
        }
        if(best_provider != ""){
            print best_provider;
            next;
        }
        best_short = "";
        for(i=1;i<=n;i++){
            if(a[i] == "") continue;
            if(best_short == "" || length(a[i]) < length(best_short)) best_short = a[i];
        }
        if(best_short != "") print best_short;
        else print $0;
    }')"

    CANDIDATE="$(printf '%s' "$CANDIDATE" | awk '{$1=$1; print}')"

    CLEAN_TITLE="$CANDIDATE"

    LOW_CLASS="$(printf '%s' "$CLASS" | tr '[:upper:]' '[:lower:]')"
    LOW_RESOURCE="$(printf '%s' "$RESOURCE" | tr '[:upper:]' '[:lower:]')"
    LOW_CLEAN="$(printf '%s' "$CLEAN_TITLE" | tr '[:upper:]' '[:lower:]')"

    case "$LOW_CLASS" in
        code|visual-studio-code|vscode|vscodium) CLEAN_TITLE="Visual Studio Code" ;;
        sublime|sublime_text) CLEAN_TITLE="Sublime Text" ;;
        atom) CLEAN_TITLE="Atom" ;;
        emacs) CLEAN_TITLE="Emacs" ;;
        gvim|vim) CLEAN_TITLE="Vim" ;;
        idea|jetbrains*) CLEAN_TITLE="IntelliJ IDEA" ;;
    esac

    case "$LOW_RESOURCE" in
        code|visual-studio-code|vscode|vscodium) CLEAN_TITLE="Visual Studio Code" ;;
        sublime|sublime_text) CLEAN_TITLE="Sublime Text" ;;
    esac

    GENERIC_RE='^(untitled|sem título|sem titulo|new tab|nova guia|cenas|window|terminal|documento|nova)$'
    CT_LEN=${#CLEAN_TITLE}
    if [[ $CT_LEN -le 4 ]] || [[ "$LOW_CLEAN" =~ $GENERIC_RE ]]; then
        if [ -n "$RESOURCE" ]; then
            CLEAN_TITLE="$(printf '%s' "$RESOURCE" | awk '{ $0=toupper($0); print }')"
        elif [ -n "$CLASS" ]; then
            CLEAN_TITLE="$(printf '%s' "$CLASS" | awk '{ $0=toupper($0); print }')"
        fi
    fi

    TITLE_Q=$(printf "%q" "$CLEAN_TITLE")
    
    FULL_WINDOW_BLOCK=$(
        printf "WINDOW_%s_DESKTOP=%s^WINDOW_%s_MONITOR=%s^WINDOW_%s_WID=%s^WINDOW_%s_CLASS=%s^WINDOW_%s_RESOURCE=%s^WINDOW_%s_POS_X=%s^WINDOW_%s_POS_Y=%s^WINDOW_%s_WIDTH=%s^WINDOW_%s_HEIGHT=%s^WINDOW_%s_MIN_WIDTH=%s^WINDOW_%s_MIN_HEIGHT=%s^WINDOW_%s_TITLE=%s^WINDOW_%s_USER_TIME=%s^WINDOW_%s_PID=%s^WINDOW_%s_PROCESS_START_TIME=%s" \
        "$WINDOW_COUNT" "$DESKTOP" \
        "$WINDOW_COUNT" "$MONITOR_ID" \
        "$WINDOW_COUNT" "$WID" \
        "$WINDOW_COUNT" "$CLASS_Q" \
        "$WINDOW_COUNT" "$RESOURCE_Q" \
        "$WINDOW_COUNT" "$POS_X" \
        "$WINDOW_COUNT" "$POS_Y" \
        "$WINDOW_COUNT" "$WIDTH" \
        "$WINDOW_COUNT" "$HEIGHT" \
        "$WINDOW_COUNT" "$MIN_W" \
        "$WINDOW_COUNT" "$MIN_H" \
        "$WINDOW_COUNT" "$TITLE_Q" \
        "$WINDOW_COUNT" "$USER_TIME_DEC" \
        "$WINDOW_COUNT" "$PID" \
        "$WINDOW_COUNT" "$P_START_TIME_DEC"
    )
    
    printf "%s|%s|%s|%s\n" "$DESKTOP" "$MONITOR_ID" "$WID" "$FULL_WINDOW_BLOCK" >> "$TEMP_UNSORTED_FINAL"
    
    log "LOOP END: WID $WID processed."

done < "$TEMP_UNSORTED_FILE"

log "BASH: DATA FETCH LOOP FINISHED."

# ===== FINAL DETERMINISTIC SORT =====
SORTED_DATA=$(sort -t '|' -k1,1n -k2,2n -k3,3 "$TEMP_UNSORTED_FINAL")

# ===== FINAL FORMATTING AND VALIDATION =====
if [ "$WINDOW_COUNT" -eq 0 ]; then
    log "SUCCESS (EMPTY): NO STANDARD WINDOWS FOUND TO MANAGE. WINDOW_COUNT=0."
    printf "WINDOW_COUNT=0\n" > "$DATA_FILE"
    cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
    printf "✅ M03 SUCCESS: Captured 0 active window(s).\n"
    log "MODULE 03 END (SUCCESS - No Windows)"
    exit 0
fi

# ===== RE-INDEXING =====
FINAL_WINDOW_COUNT_REINDEXED=0

: > "$TEMP_FINAL_DATA"

while IFS='|' read -r SORT_DESKTOP SORT_MONITOR SORT_WID FULL_WINDOW_BLOCK; do
    FINAL_WINDOW_COUNT_REINDEXED=$((FINAL_WINDOW_COUNT_REINDEXED + 1))
    
    REINDEXED_LINE=$(echo "$FULL_WINDOW_BLOCK" | sed "s/WINDOW_[0-9]*_/WINDOW_${FINAL_WINDOW_COUNT_REINDEXED}_/g")
    
    echo "$REINDEXED_LINE" | tr '^' '\n' >> "$TEMP_FINAL_DATA"
    
done <<< "$SORTED_DATA"

# ===== OUTPUT GENERATION AND STATE PERSISTENCE =====
log "GENERATING FINAL OUTPUT WITH HIERARCHY HEADERS AND PERSISTING STATE"

printf "WINDOW_COUNT=%s\n" "$FINAL_WINDOW_COUNT_REINDEXED" > "$DATA_FILE"

CURRENT_DESKTOP=""
CURRENT_MONITOR=""
WINDOW_BLOCK_BUFFER=""

while IFS= read -r line; do

    if [[ "$line" == WINDOW_?*_DESKTOP=* ]]; then
        WINDOW_BLOCK_BUFFER=""
        NEW_DESKTOP=${line##*=}

        if [ "$NEW_DESKTOP" != "$CURRENT_DESKTOP" ]; then

            DESKTOP_NAME_STR=${DESKTOP_NAME[$NEW_DESKTOP]:-""}
            VISUAL_INDEX=""
            if [ -n "$DESKTOP_NAME_STR" ]; then
                VISUAL_INDEX=$(echo "$DESKTOP_NAME_STR" | cut -d':' -f1 | tr -d ' ' | tr -d "'")
            fi

            printf "\n# ================= DESKTOP %s (VISUAL INDEX: %s | NAME: %s) =================\n" "$NEW_DESKTOP" "$VISUAL_INDEX" "$DESKTOP_NAME_STR" >> "$DATA_FILE"

            CURRENT_DESKTOP="$NEW_DESKTOP"
            CURRENT_MONITOR=""
        fi

        WINDOW_BLOCK_BUFFER+="$line"$'\n'

    elif [[ "$line" == WINDOW_?*_MONITOR=* ]]; then
        NEW_MONITOR=${line##*=}

        if [ "$NEW_MONITOR" != "$CURRENT_MONITOR" ]; then
            MONITOR_NAME_STR=${MONITOR_NAME[$NEW_MONITOR]:-""}

            printf "\n# ------------- MONITOR %s (%s) -------------\n" "$NEW_MONITOR" "$MONITOR_NAME_STR" >> "$DATA_FILE"
            CURRENT_MONITOR="$NEW_MONITOR"
        fi

        WINDOW_BLOCK_BUFFER+="$line"$'\n'
    
    elif [[ "$line" == WINDOW_?*_WID=* ]]; then
        WINDOW_INDEX=$(echo "$line" | cut -d'_' -f2)

        printf "\n# --- WINDOW %s ---\n" "$WINDOW_INDEX" >> "$DATA_FILE"

        printf "%s" "$WINDOW_BLOCK_BUFFER" >> "$DATA_FILE"
        WINDOW_BLOCK_BUFFER=""

        printf "%s\n" "$line" >> "$DATA_FILE"

    else
        printf "%s\n" "$line" >> "$DATA_FILE"
    fi

done < "$TEMP_FINAL_DATA"

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "DATA STATE SUCCESSFULLY BACKED UP."

printf "✅ M03 SUCCESS: Captured %s active window(s), including HINTS.\n" "$FINAL_WINDOW_COUNT_REINDEXED"
log "MODULE 03 END (SUCCESS)"
exit 0