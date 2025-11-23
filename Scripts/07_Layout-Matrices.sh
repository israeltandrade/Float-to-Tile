#!/usr/bin/env bash

# ===== FILE: 07_Layout-Matrices.sh =====
# ===== Full names in MATRICIAL PREVIEW; ASCII PREVIEW uses truncated names; 2D ASCII uses same cell style as 3D for consistent equalization. =====

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# ===== DIRECTORY GUARANTEE =====
mkdir -p "$ROOT_DIR/Logs" \
         "$ROOT_DIR/Data" \
         "$ROOT_DIR/Last-Valid-States"

DATA_DIR="$ROOT_DIR/Data"
LOG_DIR="$ROOT_DIR/Logs"
LAST_STATE_DIR="$ROOT_DIR/Last-Valid-States"

DESKTOP_DATA_FILE="$DATA_DIR/02_Desktop-Details.data"
CYCLE_MAP_FILE="$DATA_DIR/06_Window-Cycle-Map.data"
MONITOR_DATA_FILE="$DATA_DIR/01_Screen-Resolution.data"
WINDOW_DATA_FILE="$DATA_DIR/03_Window-List.data"

LOG_FILE="$LOG_DIR/07_Layout-Matrices.log"
DATA_FILE="$DATA_DIR/07_Layout-Matrices.data"
LAST_VALID_STATE_FILE="$LAST_STATE_DIR/07_Layout-Matrices.last-valid-state"

TEMP_CYCLE_LISTS_FILE="/tmp/07_cycle_lists_$$"
TEMP_WINDOW_MAP="/tmp/07_window_map_$$"
declare -A DESKTOP_NAME_MAP
declare -a MONITOR_NAME
declare -A WID_TO_TITLE

log() {
    mkdir -p "$LOG_DIR"
    printf '[%s] %s\n' "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

trunc() {
    local s="$1"; local n="$2"
    if [ "${#s}" -le "$n" ]; then
        printf '%s' "$s"
    else
        printf '%s' "${s:0:$((n-1))}…"
    fi
}

pad_right() {
    local s="$1"; local w="$2"
    printf '%-*s' "$w" "$s"
}

center() {
    local s="$1"; local w="$2"
    local len=${#s}
    if [ "$len" -ge "$w" ]; then
        printf '%s' "${s:0:$w}"
    else
        local left=$(( (w - len) / 2 ))
        local right=$(( w - len - left ))
        printf '%*s%s%*s' "$left" '' "$s" "$right" ''
    fi
}

# ===== READ MONITOR NAMES =====
read_monitor_names() {
    if [[ -f "$MONITOR_DATA_FILE" ]]; then
        MONITOR_COUNT=$(grep -E '^MONITOR_COUNT=' "$MONITOR_DATA_FILE" | cut -d'=' -f2)
        if ! [[ "$MONITOR_COUNT" =~ ^[0-9]+$ ]]; then MONITOR_COUNT=0; fi
        local m_idx=1
        while [ "$m_idx" -le "$MONITOR_COUNT" ]; do
            MONITOR_NAME[$m_idx]=$(grep -E "^MONITOR_${m_idx}_NAME=" "$MONITOR_DATA_FILE" | cut -d'=' -f2)
            MONITOR_NAME[$m_idx]="$(printf '%s' "${MONITOR_NAME[$m_idx]}" | sed -E "s/^['\"]?//; s/['\"]?$//; s/^ *//; s/ *$//")"
            m_idx=$((m_idx + 1))
        done
    fi
}

# ===== BUILD WID -> TITLE MAP =====
build_wid_title_map() {
    if [[ -f "$WINDOW_DATA_FILE" ]]; then
        grep -E "^(WINDOW_COUNT|WINDOW_[0-9]+_(WID|TITLE))=" "$WINDOW_DATA_FILE" > "$TEMP_WINDOW_MAP" || true
        if [[ -s "$TEMP_WINDOW_MAP" ]]; then
            # shellcheck disable=SC1090
            source "$TEMP_WINDOW_MAP" 2>/dev/null || true
            if [[ -n "${WINDOW_COUNT:-}" ]]; then
                for ((i = 1; i <= WINDOW_COUNT; i++)); do
                    WID_VAR="WINDOW_${i}_WID"; TITLE_VAR="WINDOW_${i}_TITLE"
                    WID_VAL=${!WID_VAR:-}; TITLE_VAL=${!TITLE_VAR:-}
                    if [[ -n "$WID_VAL" ]]; then
                        if [[ -n "$TITLE_VAL" ]]; then
                            CLEAN="$(printf '%s' "$TITLE_VAL" | sed -E 's/^["'\'']?//; s/["'\'']?$//')"
                            DECODED="$(printf '%b' "$CLEAN" 2>/dev/null || printf '%s' "$CLEAN")"
                            DECODED="$(printf '%s' "$DECODED" | sed -E 's/^ *//; s/ *$//')"
                            WID_TO_TITLE["$WID_VAL"]="$DECODED"
                        else
                            WID_TO_TITLE["$WID_VAL"]=""
                        fi
                    fi
                done
            fi
        fi
    fi
}

trap 'rm -f "$TEMP_CYCLE_LISTS_FILE" "$TEMP_WINDOW_MAP"' EXIT

: > "$LOG_FILE"
: > "$DATA_FILE"
log 'MODULE 07 START (v2.6.13 - full MATRICIAL names; ASCII aligned)'

TOTAL_GROUPS=0

if [[ ! -f "$CYCLE_MAP_FILE" ]]; then
    log "ERROR: Required data file $CYCLE_MAP_FILE not found. Run M06 first."
    printf '%s\n' "❌ M07 FAILED: Missing cycle map data." ; exit 1
fi
if [[ ! -f "$DESKTOP_DATA_FILE" ]]; then
    log "ERROR: Desktop details data file not found at $DESKTOP_DATA_FILE."
    printf '%s\n' "❌ M07 FAILED: Missing desktop details data." ; exit 1
fi

# load desktops
# shellcheck disable=SC1090
source "$DESKTOP_DATA_FILE"
if [ -n "${DESKTOP_COUNT:-}" ] && [ "$DESKTOP_COUNT" -gt 0 ]; then
    for ((i=0;i<DESKTOP_COUNT;i++)); do
        NAME_VAR="DESKTOP_${i}_NAME"
        NAME_STR=${!NAME_VAR:-'???'}
        VISUAL_INDEX_STR=""
        if [ -n "$NAME_STR" ]; then VISUAL_INDEX_STR=$(echo "$NAME_STR" | cut -d':' -f1 | sed 's/^ *//; s/ *$//'); fi
        DESKTOP_NAME_MAP["$i"]="$VISUAL_INDEX_STR : $NAME_STR"
    done
fi

read_monitor_names
build_wid_title_map
log "INFO: Loaded monitor names and WID->TITLE map"

if ! grep -E "^[[:space:]]*D[0-9]+_M[0-9]+_CYCLE_LIST=" "$CYCLE_MAP_FILE" > "$TEMP_CYCLE_LISTS_FILE"; then
    log "WARNING: No CYCLE_LIST data found in M06. Exiting."
    printf '%s\n' "✅ M07 SUCCESS: No cycle lists to process." ; exit 0
fi

MAX_NAME_WIDTH=20
SEP=" | "

while IFS='=' read -r VAR_NAME WID_LIST; do
    KEY=$(printf '%s' "$VAR_NAME" | sed 's/_CYCLE_LIST//; s/^ *//; s/ *$//')
    DESKTOP_ID=$(printf '%s' "$KEY" | cut -d'_' -f1 | tr -d 'D')
    MONITOR_ID=$(printf '%s' "$KEY" | cut -d'_' -f2 | tr -d 'M')

    WID_LIST_CLEANED=$(printf '%s' "$WID_LIST" | tr -d "'" | sed 's/^ *//; s/ *$//')
    OLD_IFS=$IFS; IFS=' ' ; read -ra WIDS <<< "$WID_LIST_CLEANED"; IFS=$OLD_IFS
    COUNT=${#WIDS[@]}

    if [ "$COUNT" -le 0 ]; then continue; fi
    TOTAL_GROUPS=$((TOTAL_GROUPS+1))

    DESKTOP_CONTEXT="${DESKTOP_NAME_MAP["$DESKTOP_ID"]:-'Unknown Desktop'}"
    VISUAL_INDEX="$(printf '%s' "$DESKTOP_CONTEXT" | cut -d':' -f1 | sed 's/^ *//; s/ *$//')"
    DESKTOP_NAME_FULL="$(printf '%s' "$DESKTOP_CONTEXT" | cut -d':' -f2- | sed 's/^ *//; s/ *$//')"

    printf '\n# ================= DESKTOP %s (VISUAL INDEX: %s | NAME: %s) =================\n' "$DESKTOP_ID" "$VISUAL_INDEX" "$DESKTOP_NAME_FULL" >> "$DATA_FILE"
    printf '\n# ------------- MONITOR %s (%s) -------------\n' "$MONITOR_ID" "${MONITOR_NAME[$MONITOR_ID]:-UnknownMonitor}" >> "$DATA_FILE"

    FULL_NAME_LIST=()
    NAME_LIST=()
    for wid in "${WIDS[@]}"; do
        raw="${WID_TO_TITLE[$wid]:-Unknown}"
        FULL_NAME_LIST+=( "$raw" )
        NAME_LIST+=( "$(trunc "$raw" "$MAX_NAME_WIDTH")" )
    done

    # ===== 2D: MATRICIAL PREVIEW (full names) =====
    printf '\n# --- 2D Matrix (Master/Stack Vertical) ---\n' >> "$DATA_FILE"
    printf '# MATRICIAL PREVIEW (2D):\n' >> "$DATA_FILE"
    printf '# %s_MATRIX_2D_0=%s\n' "$KEY" "${FULL_NAME_LIST[0]:-Unknown}" >> "$DATA_FILE"
    if [ "$COUNT" -gt 1 ]; then
        for ((i=1;i<COUNT;i++)); do
            printf '# %s_MATRIX_2D_1_%s=%s\n' "$KEY" "$((i-1))" "${FULL_NAME_LIST[$i]:-Unknown}" >> "$DATA_FILE"
        done
    fi

    # ===== 2D ASCII PREVIEW (truncated, equalized cells) =====
    printf '\n# === 2D Matrix (Master/Stack Vertical) ASCII PREVIEW ===\n' >> "$DATA_FILE"
    rows=$(( COUNT > 1 ? COUNT-1 : 1 ))

    maxlen=0
    for v in "${NAME_LIST[@]}"; do
        if [ -n "$v" ]; then
            l=${#v}
            if [ "$l" -gt "$maxlen" ]; then maxlen=$l; fi
        fi
    done
    inner_w=$(( maxlen > MAX_NAME_WIDTH ? maxlen : MAX_NAME_WIDTH ))
    cell_w=$(( inner_w + 6 ))

    build_cell_local() {
        local name="$1"
        local centered
        centered="$(center "$(trunc "$name" "$inner_w")" "$inner_w")"
        printf '%-*s' "$cell_w" "$(printf -- '- %s - ' "$centered")"
    }

    printf '# %s %s %s |\n' "$(pad_right '--- Master ---' $inner_w)" "$SEP" "$(pad_right '--- Stack ----' $inner_w)" >> "$DATA_FILE"

    for ((r=0;r<rows;r++)); do
        mcell="$(build_cell_local "${NAME_LIST[0]:-Unknown}")"
        scell="$(build_cell_local "${NAME_LIST[$((r+1))]:-''}")"
        printf '# %s %s %s |\n' "$mcell" "$SEP" "$scell" >> "$DATA_FILE"
    done
    printf '\n' >> "$DATA_FILE"

    # ===== 3D: MATRICIAL PREVIEW (full names) =====
    printf '# --- 3D Matrix (Fibonacci/Dynamic Stack) ---\n' >> "$DATA_FILE"
    printf '# MATRICIAL PREVIEW (3D):\n' >> "$DATA_FILE"
    if [ "$COUNT" -eq 1 ]; then
        printf '# %s_MATRIX_3D_0=%s\n' "$KEY" "${FULL_NAME_LIST[0]:-Unknown}" >> "$DATA_FILE"
    elif [ "$COUNT" -eq 2 ]; then
        printf '# %s_MATRIX_3D_0=%s\n# %s_MATRIX_3D_1=%s\n' "$KEY" "${FULL_NAME_LIST[0]:-Unknown}" "$KEY" "${FULL_NAME_LIST[1]:-Unknown}" >> "$DATA_FILE"
    elif [ "$COUNT" -eq 3 ]; then
        printf '# %s_MATRIX_3D_0=%s\n# %s_MATRIX_3D_1_0=%s\n# %s_MATRIX_3D_1_1=%s\n' \
            "$KEY" "${FULL_NAME_LIST[0]:-Unknown}" \
            "$KEY" "${FULL_NAME_LIST[1]:-Unknown}" \
            "$KEY" "${FULL_NAME_LIST[2]:-Unknown}" >> "$DATA_FILE"
    else
        printf '# %s_MATRIX_3D_0=%s\n# %s_MATRIX_3D_1_0=%s\n# %s_MATRIX_3D_1_1_0=%s\n# %s_MATRIX_3D_1_1_1=%s\n' \
            "$KEY" "${FULL_NAME_LIST[0]:-Unknown}" \
            "$KEY" "${FULL_NAME_LIST[1]:-Unknown}" \
            "$KEY" "${FULL_NAME_LIST[2]:-Unknown}" \
            "$KEY" "${FULL_NAME_LIST[3]:-Unknown}" >> "$DATA_FILE"
        if [ "$COUNT" -gt 4 ]; then
            for ((i=4;i<COUNT;i++)); do
                printf '# %s_MATRIX_3D_1_1_1_%s=%s\n' "$KEY" "$((i-4))" "${FULL_NAME_LIST[$i]:-Unknown}" >> "$DATA_FILE"
            done
        fi
    fi

    # ===== 3D ASCII PREVIEW (matricial, truncated names for alignment) =====
    printf '\n# === 3D Matrix (Fibonacci/Dynamic Stack) ASCII PREVIEW (MATRICIAL - 3 levels) ===\n' >> "$DATA_FILE"

    level0=(); level1=(); level2=(); level3=()
    level0+=( "${NAME_LIST[0]:-Unknown}" )
    if [ "${#NAME_LIST[@]}" -ge 2 ]; then level1+=( "${NAME_LIST[1]:-}" ); fi
    if [ "${#NAME_LIST[@]}" -ge 3 ]; then
        level2+=( "${NAME_LIST[2]:-}" )
        if [ "${#NAME_LIST[@]}" -ge 4 ]; then level2+=( "${NAME_LIST[3]:-}" ); fi
    fi
    if [ "${#NAME_LIST[@]}" -ge 5 ]; then
        for ((i=4;i<${#NAME_LIST[@]};i++)); do level3+=( "${NAME_LIST[$i]}" ); done
    fi

    num_level2=${#level2[@]}
    if [ "$num_level2" -lt 1 ]; then num_level2=1; fi
    display_cols=$((1 + num_level2))

    maxlen=0
    for v in "${level0[@]}" "${level1[@]}" "${level2[@]}" "${level3[@]}"; do
        if [ -n "$v" ]; then
            l=${#v}
            if [ "$l" -gt "$maxlen" ]; then maxlen=$l; fi
        fi
    done
    inner_w=$(( maxlen > MAX_NAME_WIDTH ? maxlen : MAX_NAME_WIDTH ))
    cell_w=$(( inner_w + 6 ))

    build_cell() {
        local name="$1"
        local centered
        centered="$(center "$(trunc "$name" "$inner_w")" "$inner_w")"
        local raw
        raw="$(printf -- '- %s - ' "$centered")"
        printf '%-*s' "$cell_w" "$raw"
    }

    row0=(); row1=(); row2=()
    for ((c=0;c<display_cols;c++)); do
        row0+=( "$(printf '%*s' "$cell_w" '')" )
        row1+=( "$(printf '%*s' "$cell_w" '')" )
        row2+=( "$(printf '%*s' "$cell_w" '')" )
    done

    row0[0]="$(build_cell "${level0[0]:-}")"
    for ((c=1;c<display_cols;c++)); do
        if [ "${#level1[@]}" -ge 1 ]; then
            row0[$c]="$(build_cell "${level1[0]:-}")"
        else
            row0[$c]="$(printf '%-*s' "$cell_w" "$(printf -- '- %s - ' "$(center '' "$inner_w")")")"
        fi
    done

    row1[0]="$(build_cell "${level0[0]:-}")"
    for ((i=0;i<num_level2;i++)); do
        col_idx=$((i+1))
        if [ "$i" -lt "${#level2[@]}" ]; then
            row1[$col_idx]="$(build_cell "${level2[$i]:-}")"
        else
            row1[$col_idx]="$(printf '%-*s' "$cell_w" "$(printf -- '- %s - ' "$(center '' "$inner_w")")")"
        fi
    done

    row2[0]="$(build_cell "${level0[0]:-}")"
    for ((c=1;c<display_cols;c++)); do
        row2[$c]="${row1[$c]}"
    done

    last_level2_col=$(( 1 + num_level2 - 1 ))
    for ((i=0;i<${#level3[@]};i++)); do
        col_idx=$(( last_level2_col + i ))
        if [ "$col_idx" -ge "$display_cols" ]; then
            col_idx=$((display_cols-1))
        fi
        row2[$col_idx]="$(build_cell "${level3[$i]:-}")"
    done

    printf '# ' >> "$DATA_FILE"
    for ((c=0;c<display_cols;c++)); do
        printf '%s' "${row0[$c]}" >> "$DATA_FILE"
        printf '| ' >> "$DATA_FILE"
    done
    printf '\n' >> "$DATA_FILE"

    printf '# ' >> "$DATA_FILE"
    for ((c=0;c<display_cols;c++)); do
        printf '%s' "${row1[$c]}" >> "$DATA_FILE"
        printf '| ' >> "$DATA_FILE"
    done
    printf '\n' >> "$DATA_FILE"

    printf '# ' >> "$DATA_FILE"
    for ((c=0;c<display_cols;c++)); do
        printf '%s' "${row2[$c]}" >> "$DATA_FILE"
        printf '| ' >> "$DATA_FILE"
    done
    printf '\n\n' >> "$DATA_FILE"

    # ===== real variable outputs (WIDs) =====
    printf '# --- 2D Matrix real variables (WIDs) ---\n' >> "$DATA_FILE"
    printf '%s_MATRIX_2D_0=%s\n' "$KEY" "${WIDS[0]}" >> "$DATA_FILE"
    if [ "$COUNT" -gt 1 ]; then
        for ((i=1;i<COUNT;i++)); do
            printf '%s_MATRIX_2D_1_%s=%s\n' "$KEY" "$((i-1))" "${WIDS[$i]}" >> "$DATA_FILE"
        done
    fi

    printf '\n# --- 3D Matrix real variables (WIDs) ---\n' >> "$DATA_FILE"
    if [ "$COUNT" -eq 1 ]; then
        printf '%s_MATRIX_3D_0=%s\n' "$KEY" "${WIDS[0]}" >> "$DATA_FILE"
    elif [ "$COUNT" -eq 2 ]; then
        printf '%s_MATRIX_3D_0=%s\n' "$KEY" "${WIDS[0]}" >> "$DATA_FILE"
        printf '%s_MATRIX_3D_1=%s\n' "$KEY" "${WIDS[1]}" >> "$DATA_FILE"
    elif [ "$COUNT" -eq 3 ]; then
        printf '%s_MATRIX_3D_0=%s\n' "$KEY" "${WIDS[0]}" >> "$DATA_FILE"
        printf '%s_MATRIX_3D_1_0=%s\n' "$KEY" "${WIDS[1]}" >> "$DATA_FILE"
        printf '%s_MATRIX_3D_1_1=%s\n' "$KEY" "${WIDS[2]}" >> "$DATA_FILE"
    else
        printf '%s_MATRIX_3D_0=%s\n' "$KEY" "${WIDS[0]}" >> "$DATA_FILE"
        printf '%s_MATRIX_3D_1_0=%s\n' "$KEY" "${WIDS[1]}" >> "$DATA_FILE"
        printf '%s_MATRIX_3D_1_1_0=%s\n' "$KEY" "${WIDS[2]}" >> "$DATA_FILE"
        printf '%s_MATRIX_3D_1_1_1=%s\n' "$KEY" "${WIDS[3]}" >> "$DATA_FILE"
        for ((i=4;i<COUNT;i++)); do
            printf '%s_MATRIX_3D_1_1_1_%s=%s\n' "$KEY" "$((i-4))" "${WIDS[$i]}" >> "$DATA_FILE"
        done
    fi

    printf '\n' >> "$DATA_FILE"
    log "INFO: Generated group $KEY (count=$COUNT) with matricial + ASCII previews."
done < "$TEMP_CYCLE_LISTS_FILE"

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "INFO: Data state successfully backed up."

printf '✅ M07 SUCCESS: Generated layout matrices for %s window groups (matricial + ASCII previews).\n' "$TOTAL_GROUPS"
log 'MODULE 07 END - SUCCESS'
exit 0