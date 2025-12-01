#!/usr/bin/env bash
# File: AC09_Focus-Prev-Window.sh
# Description: v2.3 - Focus the previous window from the pre-sorted cycle in 06_Window-Cycle-Map.data.
# Notes:
# - Uses M06 and M03 to extract desktop/monitor/titles/geometries and write a complete last-state.
# - Avoids using `local` outside functions for broader bash compatibility.

set -euo pipefail
shopt -s extglob

# ===== PATHS & INITIALIZATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC09_Focus-Prev-Window.log"
CONFIG_FILE="$ROOT_DIR/global_config.conf"
M06_FILE="$DATA_DIR/06_Window-Cycle-Map.data"
M03_FILE="$DATA_DIR/03_Window-List.data"
RUN_SH="$ROOT_DIR/run.sh"

LAST_STATE_DIR="$ROOT_DIR/Actions/Actions_Last-Valid-States"
ALT_LAST_STATE_DIR="$ROOT_DIR/Last-Valid-States"
LAST_STATE_FILE="$LAST_STATE_DIR/AC09_Focus-Prev-Window.last-valid-state"

if ! mkdir -p "$(dirname "$LOG_FILE")"; then
  echo "ERROR: cannot create log directory: $(dirname "$LOG_FILE")" >&2
  exit 1
fi

log() {
  local lvl="$1"; shift
  local msg="$*"
  printf '%s %s - %s\n' "$(date +'%Y-%m-%d %H:%M:%S')" "[$lvl]" "$msg" >> "$LOG_FILE"
}

: > "$LOG_FILE"
log "INFO" "Script started."

# ===== HELPERS (NORMALIZATION) =====
normalize_wid() {
  local w="$1"
  w="$(printf '%s' "$w" | xargs | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$w" ]]; then
    echo "0x0"; return
  fi
  if [[ "$w" =~ ^[0-9]+$ ]]; then
    printf '0x%x' "$w"; return
  fi
  w="${w#0x}"
  w="${w##+(0)}"
  if [[ -z "$w" ]]; then
    echo "0x0"
  else
    echo "0x${w}"
  fi
}

normalize_wid_list_to_array() {
  local in="$1"
  local -n outarr=$2
  outarr=()
  local rawarr
  read -r -a rawarr <<<"$in"
  for x in "${rawarr[@]}"; do
    [[ -z "$x" ]] && continue
    outarr+=( "$(normalize_wid "$x")" )
  done
}

hex_to_dec() {
  local hx="$1"
  if [[ "$hx" =~ ^0x([0-9a-fA-F]+)$ ]]; then
    printf "%d" "0x${BASH_REMATCH[1]}"
  else
    printf ''
  fi
}

write_last_state() {
  local payload tmp final
  payload="$1"
  if ! mkdir -p "$LAST_STATE_DIR"; then
    log "WARN" "Could not create last-state dir: $LAST_STATE_DIR"; return 1
  fi
  tmp="$(mktemp "${LAST_STATE_DIR}/AC09_payload.XXXXXX")" || return 1
  printf '%s\n' "$payload" > "$tmp"
  final="$(mktemp "${LAST_STATE_DIR}/AC09_payload.final.XXXXXX")" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$final"
  mv -f "$final" "$LAST_STATE_FILE"
  chmod 0644 "$LAST_STATE_FILE" 2>/dev/null || true
  return 0
}

# ===== LOAD ENVIRONMENT (run.sh, config, data) =====

# Prefer .data; if missing, try .last-valid-state in known dirs.
m03_found=false
m06_found=false

if [[ -f "$M03_FILE" && -s "$M03_FILE" ]]; then
  m03_found=true
  log "INFO" "Found M03 data: $M03_FILE"
fi

if [[ -f "$M06_FILE" && -s "$M06_FILE" ]]; then
  m06_found=true
  log "INFO" "Found M06 data: $M06_FILE"
fi

try_last_valid_state() {
  local base_name="$1"    # e.g., 03_Window-List
  local varname="$2"      # variable name to update (M03_FILE / M06_FILE)
  local data_path="${!varname}"
  if [[ -f "$data_path" && -s "$data_path" ]]; then
    return 0
  fi
  local candidate
  for dir in "$LAST_STATE_DIR" "$ALT_LAST_STATE_DIR" "$ROOT_DIR/Actions_Last-Valid-States"; do
    candidate="$dir/${base_name}.last-valid-state"
    if [[ -f "$candidate" && -s "$candidate" ]]; then
      eval "$varname=\"\$candidate\""
      log "INFO" "Using last-valid-state for ${base_name}: $candidate"
      return 0
    fi
  done
  return 1
}

if ! $m03_found; then
  if try_last_valid_state "03_Window-List" "M03_FILE"; then
    m03_found=true
  else
    log "INFO" "M03 .data not found; no last-valid-state found yet."
  fi
fi

if ! $m06_found; then
  if try_last_valid_state "06_Window-Cycle-Map" "M06_FILE"; then
    m06_found=true
  else
    log "INFO" "M06 .data not found; no last-valid-state found yet."
  fi
fi

# If both present (either .data or .last-valid-state), skip running run.sh
if $m03_found && $m06_found; then
  log "INFO" "Both M03 and M06 available. Skipping run.sh."
else
  if [[ -x "$RUN_SH" ]]; then
    log "INFO" "Needed data missing; executing run.sh to regenerate data."
    if ! "$RUN_SH"; then
      log "WARNING" "run.sh failed (continuing — assuming existing data in $DATA_DIR)."
    else
      log "INFO" "run.sh executed successfully."
    fi
    # re-check after run.sh
    if [[ -f "$M03_FILE" && -s "$M03_FILE" ]]; then
      m03_found=true
      log "INFO" "M03 present after run.sh: $M03_FILE"
    fi
    if [[ -f "$M06_FILE" && -s "$M06_FILE" ]]; then
      m06_found=true
      log "INFO" "M06 present after run.sh: $M06_FILE"
    fi
  else
    log "WARNING" "run.sh not found/executable: $RUN_SH. Will attempt to proceed with any available data or last-valid-state."
  fi
fi

# Load config if present
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  log "INFO" "Loaded $CONFIG_FILE."
else
  log "WARNING" "Config file not found: $CONFIG_FILE. Proceeding with defaults."
fi

# Ensure M03 and M06 are present now (either .data or .last-valid-state)
if [[ -f "$M03_FILE" && -s "$M03_FILE" ]]; then
  source "$M03_FILE"
  log "INFO" "Loaded $M03_FILE."
else
  log "ERROR" "M03 file not found: $M03_FILE. Exiting."
  printf "❌ AC09 FAILED: Missing M03 data.\n"; exit 1
fi

if [[ -f "$M06_FILE" && -s "$M06_FILE" ]]; then
  source "$M06_FILE"
  log "INFO" "Loaded $M06_FILE."
else
  log "ERROR" "M06 file not found: $M06_FILE. Exiting."
  printf "❌ AC09 FAILED: Missing M06 cycle map data.\n"; exit 1
fi

# ===== BUILD MAPS FROM M03 =====
declare -A MAP_WID_TITLE MAP_WID_DESKTOP MAP_WID_MONITOR MAP_WID_X MAP_WID_Y MAP_WID_W MAP_WID_H

for ((i=1; i<=${WINDOW_COUNT:-0}; i++)); do
  WID_VAR="WINDOW_${i}_WID"
  TITLE_VAR="WINDOW_${i}_TITLE"
  DESK_VAR="WINDOW_${i}_DESKTOP"
  MON_VAR="WINDOW_${i}_MONITOR"
  X_VAR="WINDOW_${i}_POS_X"
  Y_VAR="WINDOW_${i}_POS_Y"
  W_VAR="WINDOW_${i}_WIDTH"
  H_VAR="WINDOW_${i}_HEIGHT"

  WID_VAL="${!WID_VAR:-}"
  TITLE_VAL="${!TITLE_VAR:-}"
  DESK_VAL="${!DESK_VAR:-}"
  MON_VAL="${!MON_VAR:-}"
  X_VAL="${!X_VAR:-}"
  Y_VAL="${!Y_VAR:-}"
  W_VAL="${!W_VAR:-}"
  H_VAL="${!H_VAR:-}"

  if [[ -n "$WID_VAL" ]]; then
    norm="$(normalize_wid "$WID_VAL")"
    clean_title="$(printf '%s' "$TITLE_VAL" | tr -d '\r' | tr '\n' ' ' | tr '\t' ' ')"
    MAP_WID_TITLE["$norm"]="$clean_title"
    MAP_WID_DESKTOP["$norm"]="${DESK_VAL:-}"
    MAP_WID_MONITOR["$norm"]="${MON_VAL:-}"
    MAP_WID_X["$norm"]="${X_VAL:-}"
    MAP_WID_Y["$norm"]="${Y_VAL:-}"
    MAP_WID_W["$norm"]="${W_VAL:-}"
    MAP_WID_H["$norm"]="${H_VAL:-}"
  fi
done

# ===== DETERMINE CURRENT WID =====
ACTIVE_DESKTOP="${ACTIVE_DESKTOP:-0}"
ACTIVE_MONITOR="${ACTIVE_MONITOR:-0}"
ACTIVE_WID="${ACTIVE_WID:-0x0}"

log "INFO" "Initial ACTIVE_DESKTOP=$ACTIVE_DESKTOP ACTIVE_MONITOR=$ACTIVE_MONITOR ACTIVE_WID=$ACTIVE_WID"

CURRENT_WID="$(normalize_wid "$ACTIVE_WID")"
log "INFO" "Normalized ACTIVE_WID => $CURRENT_WID"

if [[ "$CURRENT_WID" == "0x0" ]]; then
  if command -v xdotool &>/dev/null; then
    XD_DEC="$(xdotool getwindowfocus 2>/dev/null || true)"
    if [[ -n "$XD_DEC" && "$XD_DEC" =~ ^[0-9]+$ ]]; then
      CURRENT_WID="$(normalize_wid "$XD_DEC")"
      log "INFO" "xdotool returned window focus: $XD_DEC -> $CURRENT_WID"
    else
      log "WARNING" "xdotool getwindowfocus did not return a valid WID."
    fi
  else
    log "WARNING" "xdotool not available for fallback."
  fi
fi

if [[ -z "$CURRENT_WID" || "$CURRENT_WID" == "0x0" ]]; then
  log "ERROR" "CURRENT_WID invalid (0x0). Cannot determine group."
  printf "⚠️ AC09 SKIPPED: Current WID invalid (0x0).\n"; exit 0
fi

# ===== FIND CURRENT WID INSIDE CYCLE LISTS =====
FOUND_GROUP_VAR=""
FOUND_INDEX=-1
FOUND_CYCLE_ARRAY=()
FOUND_COUNT=0

find_current_wid_group() {
  while IFS= read -r var; do
    [[ "$var" != *_CYCLE_LIST ]] && continue
    cycle_value="${!var:-}"
    normalize_wid_list_to_array "$cycle_value" tmp_arr
    if ((${#tmp_arr[@]} > 0)); then
      for i in "${!tmp_arr[@]}"; do
        if [[ "${tmp_arr[$i]}" == "$CURRENT_WID" ]]; then
          FOUND_GROUP_VAR="$var"
          FOUND_INDEX="$i"
          FOUND_CYCLE_ARRAY=("${tmp_arr[@]}")
          local count_var="${var%_CYCLE_LIST}_COUNT"
          if [[ -n "${!count_var:-}" && "${!count_var}" =~ ^[0-9]+$ ]]; then
            FOUND_COUNT="${!count_var}"
          else
            FOUND_COUNT="${#FOUND_CYCLE_ARRAY[@]}"
          fi
          return 0
        fi
      done
    fi
  done < <(compgen -v)
  return 1
}

if ! find_current_wid_group; then
  log "INFO" "WID $CURRENT_WID not found in any *_CYCLE_LIST in M06."
  printf "⚠️ AC09 SKIPPED: Window %s not present in any cycle list.\n" "$CURRENT_WID"
  exit 0
fi

# ===== COMPUTE PREVIOUS INDEX & WID =====
GROUP_KEY="${FOUND_GROUP_VAR%_CYCLE_LIST}"
log "INFO" "Found WID in group $GROUP_KEY (var $FOUND_GROUP_VAR), index $FOUND_INDEX, group count $FOUND_COUNT"

if ((${#FOUND_CYCLE_ARRAY[@]} == 0)); then
  log "ERROR" "Cycle array empty for $FOUND_GROUP_VAR despite var existing."
  printf "❌ AC09 FAILED: Empty cycle list for %s\n" "$FOUND_GROUP_VAR"; exit 1
fi

LEN=${#FOUND_CYCLE_ARRAY[@]}
PREV_INDEX=$(( (FOUND_INDEX - 1 + LEN) % LEN ))
PREV_WID="${FOUND_CYCLE_ARRAY[$PREV_INDEX]}"

log "INFO" "Cycling: current index $FOUND_INDEX -> prev index $PREV_INDEX; PREV_WID=$PREV_WID"

# ===== FOCUS PREV_WID =====
if command -v wmctrl &>/dev/null; then
  log "INFO" "Attempting to focus $PREV_WID with wmctrl."
  if ! wmctrl -i -a "$PREV_WID" ; then
    DEC="$(hex_to_dec "$PREV_WID")"
    if [[ -n "$DEC" ]]; then
      if ! wmctrl -i -a "$DEC"; then
        log "ERROR" "wmctrl failed for $PREV_WID and decimal $DEC."
        printf "❌ AC09 FAILED: wmctrl failed to focus %s (also tried %s).\n" "$PREV_WID" "$DEC"; exit 1
      else
        log "INFO" "wmctrl focused $PREV_WID using decimal $DEC."
      fi
    else
      log "ERROR" "Unexpected PREV_WID format: $PREV_WID"
      printf "❌ AC09 FAILED: prev wid format invalid: %s\n" "$PREV_WID"; exit 1
    fi
  else
    log "SUCCESS" "Focused $PREV_WID successfully."
  fi
else
  log "ERROR" "wmctrl not available on system."
  printf "❌ AC09 FAILED: wmctrl not available.\n"; exit 1
fi

# ===== EXTRACT GROUP DESKTOP/MONITOR =====
GROUP_DESKTOP=""
GROUP_MONITOR=""
if [[ "$GROUP_KEY" =~ ^D([0-9]+)_M([0-9]+)$ ]]; then
  GROUP_DESKTOP="${BASH_REMATCH[1]}"
  GROUP_MONITOR="${BASH_REMATCH[2]}"
else
  GROUP_DESKTOP="${MAP_WID_DESKTOP[$CURRENT_WID]:-${MAP_WID_DESKTOP[$PREV_WID]:-}}"
  GROUP_MONITOR="${MAP_WID_MONITOR[$CURRENT_WID]:-${MAP_WID_MONITOR[$PREV_WID]:-}}"
fi

# ===== PREPARE NAMES & GEOMETRIES =====
CURRENT_WINDOW_NAME="${MAP_WID_TITLE[$CURRENT_WID]:-unknown}"
PREV_WINDOW_NAME="${MAP_WID_TITLE[$PREV_WID]:-unknown}"

CURRENT_X="${MAP_WID_X[$CURRENT_WID]:-}"
CURRENT_Y="${MAP_WID_Y[$CURRENT_WID]:-}"
CURRENT_W="${MAP_WID_W[$CURRENT_WID]:-}"
CURRENT_H="${MAP_WID_H[$CURRENT_WID]:-}"

PREV_X="${MAP_WID_X[$PREV_WID]:-}"
PREV_Y="${MAP_WID_Y[$PREV_WID]:-}"
PREV_W="${MAP_WID_W[$PREV_WID]:-}"
PREV_H="${MAP_WID_H[$PREV_WID]:-}"

# ===== BUILD PAYLOAD & WRITE LAST-STATE =====
TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S %z')"

payload="$(cat <<EOF
### AC09 Last valid state
TIMESTAMP=${TIMESTAMP}
GROUP=${GROUP_KEY}
GROUP_DESKTOP=${GROUP_DESKTOP}
GROUP_MONITOR=${GROUP_MONITOR}

CURRENT_WID=${CURRENT_WID}
CURRENT_WINDOW_NAME=${CURRENT_WINDOW_NAME}
CURRENT_INDEX=${FOUND_INDEX}
CURRENT_GEOMETRY_X=${CURRENT_X}
CURRENT_GEOMETRY_Y=${CURRENT_Y}
CURRENT_GEOMETRY_W=${CURRENT_W}
CURRENT_GEOMETRY_H=${CURRENT_H}

PREV_WID=${PREV_WID}
PREV_WINDOW_NAME=${PREV_WINDOW_NAME}
PREV_INDEX=${PREV_INDEX}
PREV_GEOMETRY_X=${PREV_X}
PREV_GEOMETRY_Y=${PREV_Y}
PREV_GEOMETRY_W=${PREV_W}
PREV_GEOMETRY_H=${PREV_H}
EOF
)"

if write_last_state "$payload"; then
  log "INFO" "Last valid state written to $LAST_STATE_FILE"
else
  log "WARN" "Failed to write last valid state to $LAST_STATE_FILE"
fi

printf "✅ AC09 SUCCESS: Focused previous tiled window: %s (Group %s, Index %s -> %s).\n" \
  "$PREV_WID" "$GROUP_KEY" "$FOUND_INDEX" "$PREV_INDEX"

exit 0