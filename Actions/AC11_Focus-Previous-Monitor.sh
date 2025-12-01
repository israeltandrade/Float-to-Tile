#!/usr/bin/env bash
# File: AC11_Focus-Previous-Monitor.sh
# Description: v1.0 - Switch focus to the first window on the previous monitor (per desktop) when multiple monitors present.
# Notes:
# - Loads Screen/Monitor/Window data (prefers *.data, falls back to *.last-valid-state).
# - Writes last-valid-state and logs similar to AC08/AC09/AC10.
# - Ensures it only acts inside the current desktop (workspace).

set -euo pipefail
shopt -s extglob

# ===== PATHS & INITIALIZATION =====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$ROOT_DIR/Data"
LOG_FILE="$SCRIPT_DIR/Actions_Logs/AC11_Focus-Previous-Monitor.log"
CONFIG_FILE="$ROOT_DIR/global_config.conf"
M06_FILE="$DATA_DIR/06_Window-Cycle-Map.data"
M03_FILE="$DATA_DIR/03_Window-List.data"
SCR_RES_FILE="$DATA_DIR/01_Screen-Resolution.data"
MON_AREA_FILE="$DATA_DIR/04_Monitor-Area.data"
RUN_SH="$ROOT_DIR/run.sh"

LAST_STATE_DIR="$ROOT_DIR/Actions/Actions_Last-Valid-States"
ALT_LAST_STATE_DIR="$ROOT_DIR/Last-Valid-States"
LAST_STATE_FILE="$LAST_STATE_DIR/AC11_Focus-Previous-Monitor.last-valid-state"

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
  tmp="$(mktemp "${LAST_STATE_DIR}/AC11_payload.XXXXXX")" || return 1
  printf '%s\n' "$payload" > "$tmp"
  final="$(mktemp "${LAST_STATE_DIR}/AC11_payload.final.XXXXXX")" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$final"
  mv -f "$final" "$LAST_STATE_FILE"
  chmod 0644 "$LAST_STATE_FILE" 2>/dev/null || true
  return 0
}

# ===== LOAD ENVIRONMENT (run.sh, config, data) =====
try_last_valid_state() {
  local base_name="$1"
  local varname="$2"
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

m03_found=false
m06_found=false
scr_found=false
area_found=false

if [[ -f "$M03_FILE" && -s "$M03_FILE" ]]; then m03_found=true; log "INFO" "Found M03 data: $M03_FILE"; fi
if [[ -f "$M06_FILE" && -s "$M06_FILE" ]]; then m06_found=true; log "INFO" "Found M06 data: $M06_FILE"; fi
if [[ -f "$SCR_RES_FILE" && -s "$SCR_RES_FILE" ]]; then scr_found=true; log "INFO" "Found screen resolution data: $SCR_RES_FILE"; fi
if [[ -f "$MON_AREA_FILE" && -s "$MON_AREA_FILE" ]]; then area_found=true; log "INFO" "Found monitor area data: $MON_AREA_FILE"; fi

if ! $m03_found; then try_last_valid_state "03_Window-List" "M03_FILE"; m03_found=$?; fi
if ! $m06_found; then try_last_valid_state "06_Window-Cycle-Map" "M06_FILE"; m06_found=$?; fi
if ! $scr_found; then try_last_valid_state "01_Screen-Resolution" "SCR_RES_FILE"; scr_found=$?; fi
if ! $area_found; then try_last_valid_state "04_Monitor-Area" "MON_AREA_FILE"; area_found=$?; fi

# If essential missing, try run.sh
if ! ($m03_found && $m06_found && $scr_found); then
  if [[ -x "$RUN_SH" ]]; then
    log "INFO" "Essential data missing; executing run.sh to regenerate data."
    if ! "$RUN_SH"; then
      log "WARNING" "run.sh failed (continuing — attempting to use available data)."
    else
      log "INFO" "run.sh executed successfully."
    fi
    # re-check
    if [[ -f "$M03_FILE" && -s "$M03_FILE" ]]; then m03_found=true; fi
    if [[ -f "$M06_FILE" && -s "$M06_FILE" ]]; then m06_found=true; fi
    if [[ -f "$SCR_RES_FILE" && -s "$SCR_RES_FILE" ]]; then scr_found=true; fi
  else
    log "WARNING" "run.sh not found/executable: $RUN_SH. Will attempt to proceed with available data."
  fi
fi

# Load config if present
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
  log "INFO" "Loaded $CONFIG_FILE."
else
  log "WARNING" "Config file not found: $CONFIG_FILE. Proceeding with defaults."
fi

# Validate essentials
if [[ ! -f "$M03_FILE" || ! -s "$M03_FILE" ]]; then
  log "ERROR" "M03 file not found: $M03_FILE. Exiting."
  printf "❌ AC11 FAILED: Missing M03 data.\n"; exit 1
fi
if [[ ! -f "$M06_FILE" || ! -s "$M06_FILE" ]]; then
  log "ERROR" "M06 file not found: $M06_FILE. Exiting."
  printf "❌ AC11 FAILED: Missing M06 data.\n"; exit 1
fi
if [[ ! -f "$SCR_RES_FILE" || ! -s "$SCR_RES_FILE" ]]; then
  log "ERROR" "Screen resolution file not found: $SCR_RES_FILE. Exiting."
  printf "❌ AC11 FAILED: Missing 01_Screen-Resolution data.\n"; exit 1
fi

# Source files
source "$SCR_RES_FILE"
source "$M03_FILE"
source "$M06_FILE"
if [[ -f "$MON_AREA_FILE" && -s "$MON_AREA_FILE" ]]; then
  source "$MON_AREA_FILE"
  log "INFO" "Loaded $MON_AREA_FILE."
else
  log "INFO" "Monitor-area file not present; continuing without it (will use window mapping)."
fi

log "INFO" "Loaded environment data."

# ===== BUILD MAPS FROM M03 (for quick lookup) =====
declare -A MAP_WID_MONITOR MAP_WID_DESKTOP MAP_WID_TITLE

for ((i=1; i<=${WINDOW_COUNT:-0}; i++)); do
  WID_VAR="WINDOW_${i}_WID"
  DESK_VAR="WINDOW_${i}_DESKTOP"
  MON_VAR="WINDOW_${i}_MONITOR"
  TITLE_VAR="WINDOW_${i}_TITLE"

  WID_VAL="${!WID_VAR:-}"
  DESK_VAL="${!DESK_VAR:-}"
  MON_VAL="${!MON_VAR:-}"
  TITLE_VAL="${!TITLE_VAR:-}"

  if [[ -n "$WID_VAL" ]]; then
    norm="$(normalize_wid "$WID_VAL")"
    MAP_WID_MONITOR["$norm"]="${MON_VAL:-}"
    MAP_WID_DESKTOP["$norm"]="${DESK_VAL:-}"
    MAP_WID_TITLE["$norm"]="$(printf '%s' "$TITLE_VAL" | tr -d '\r' | tr '\n' ' ' | tr '\t' ' ')"
  fi
done

# ===== DETERMINE CURRENT WID & MONITOR (prefer M03 env ACTIVE_*, else map, else xdotool) =====
ACTIVE_DESKTOP="${ACTIVE_DESKTOP:-0}"
ACTIVE_MONITOR="${ACTIVE_MONITOR:-0}"
ACTIVE_WID="${ACTIVE_WID:-0x0}"

log "INFO" "Initial ACTIVE_DESKTOP=$ACTIVE_DESKTOP ACTIVE_MONITOR=$ACTIVE_MONITOR ACTIVE_WID=$ACTIVE_WID"

CURRENT_WID="$(normalize_wid "$ACTIVE_WID")"

if [[ "$CURRENT_WID" == "0x0" || -z "$CURRENT_WID" ]]; then
  if command -v xdotool &>/dev/null; then
    XD_DEC="$(xdotool getwindowfocus 2>/dev/null || true)"
    if [[ -n "$XD_DEC" && "$XD_DEC" =~ ^[0-9]+$ ]]; then
      CURRENT_WID="$(normalize_wid "$XD_DEC")"
      log "INFO" "xdotool returned window focus: $XD_DEC -> $CURRENT_WID"
    else
      log "WARNING" "xdotool did not return a valid WID; attempting to deduce from environment."
    fi
  else
    log "WARNING" "xdotool not available; attempting to deduce current WID/monitor from env and mapping."
  fi
fi

if [[ -z "$CURRENT_WID" || "$CURRENT_WID" == "0x0" ]]; then
  log "ERROR" "CURRENT_WID invalid (0x0). Cannot proceed."
  printf "⚠️ AC11 SKIPPED: Current WID invalid (0x0).\n"; exit 0
fi

# Determine current monitor: prefer ACTIVE_MONITOR, else mapping from M03
CURRENT_MONITOR="${ACTIVE_MONITOR:-}"
if [[ -z "$CURRENT_MONITOR" || "$CURRENT_MONITOR" == "0" ]]; then
  if [[ -n "${MAP_WID_MONITOR[$CURRENT_WID]:-}" ]]; then
    CURRENT_MONITOR="${MAP_WID_MONITOR[$CURRENT_WID]}"
    log "INFO" "Derived CURRENT_MONITOR from M03 mapping: $CURRENT_MONITOR"
  else
    CURRENT_MONITOR="1"
    log "WARNING" "Could not determine current monitor; defaulting to 1."
  fi
fi

# MONITOR_COUNT comes from 01_Screen-Resolution.data
MON_COUNT="${MONITOR_COUNT:-1}"
if (( MON_COUNT < 2 )); then
  log "INFO" "Only one monitor detected (MONITOR_COUNT=${MON_COUNT}). Nothing to do."
  printf "⚠️ AC11 SKIPPED: single-monitor system.\n"; exit 0
fi

# Compute previous monitor (wrap-around). Monitors are 1..MON_COUNT
CUR_MON_IDX=$((CURRENT_MONITOR + 0))
PREV_MON_IDX=$(( (CUR_MON_IDX - 2 + MON_COUNT) % MON_COUNT + 1 ))

log "INFO" "Current monitor $CUR_MON_IDX -> previous monitor $PREV_MON_IDX (MONITOR_COUNT=$MON_COUNT)"

# Determine current desktop (critical: we will act only on this desktop)
if [[ -n "${MAP_WID_DESKTOP[$CURRENT_WID]:-}" ]]; then
  CUR_DESKTOP="${MAP_WID_DESKTOP[$CURRENT_WID]}"
else
  CUR_DESKTOP="${ACTIVE_DESKTOP:-0}"
fi
log "INFO" "Operating on desktop $CUR_DESKTOP"

# Find first window in target group D{desktop}_M{prev}_CYCLE_LIST (strictly same desktop)
GROUP_VAR="D${CUR_DESKTOP}_M${PREV_MON_IDX}_CYCLE_LIST"
GROUP_VAL="${!GROUP_VAR:-}"

if [[ -z "$GROUP_VAL" ]]; then
  log "INFO" "No cycle list for desktop ${CUR_DESKTOP} monitor ${PREV_MON_IDX} (var $GROUP_VAR empty)."
  printf "⚠️ AC11 SKIPPED: No windows on monitor %s for desktop %s.\n" "$PREV_MON_IDX" "$CUR_DESKTOP"
  exit 0
fi

# normalize and extract first
normalize_wid_list_to_array "$GROUP_VAL" arr_group
if ((${#arr_group[@]} == 0)); then
  log "INFO" "Cycle list present but empty for $GROUP_VAR."
  printf "⚠️ AC11 SKIPPED: No windows in group %s.\n" "$GROUP_VAR"
  exit 0
fi

TARGET_WID="${arr_group[0]}"
TARGET_WID="$(normalize_wid "$TARGET_WID")"
log "INFO" "Candidate target first window on D${CUR_DESKTOP}_M${PREV_MON_IDX} is $TARGET_WID"

# === SAFETY CHECK: ensure TARGET_WID belongs to the SAME desktop ===
TARGET_DESKTOP="${MAP_WID_DESKTOP[$TARGET_WID]:-}"
if [[ -z "$TARGET_DESKTOP" ]]; then
  log "WARNING" "Could not determine desktop for target WID $TARGET_WID. Aborting (will not cross desktops)."
  printf "⚠️ AC11 SKIPPED: Cannot verify target desktop for %s.\n" "$TARGET_WID"
  exit 0
fi

if [[ "$TARGET_DESKTOP" != "$CUR_DESKTOP" ]]; then
  log "WARNING" "Target WID $TARGET_WID is on desktop $TARGET_DESKTOP, not current desktop $CUR_DESKTOP. Aborting (no cross-desktop focus)."
  printf "⚠️ AC11 SKIPPED: Target window is on a different desktop (%s) — refusing to switch desktops.\n" "$TARGET_DESKTOP"
  exit 0
fi

# Focus TARGET_WID
if command -v wmctrl &>/dev/null; then
  log "INFO" "Attempting to focus $TARGET_WID with wmctrl."
  if ! wmctrl -i -a "$TARGET_WID" ; then
    DEC="$(hex_to_dec "$TARGET_WID")"
    if [[ -n "$DEC" ]]; then
      if ! wmctrl -i -a "$DEC"; then
        log "ERROR" "wmctrl failed for $TARGET_WID and decimal $DEC."
        printf "❌ AC11 FAILED: wmctrl failed to focus %s (also tried %s).\n" "$TARGET_WID" "$DEC"; exit 1
      else
        log "INFO" "wmctrl focused $TARGET_WID using decimal $DEC."
      fi
    else
      log "ERROR" "Unexpected TARGET_WID format: $TARGET_WID"
      printf "❌ AC11 FAILED: target wid format invalid: %s\n" "$TARGET_WID"; exit 1
    fi
  else
    log "SUCCESS" "Focused $TARGET_WID successfully."
  fi
else
  log "ERROR" "wmctrl not available on system."
  printf "❌ AC11 FAILED: wmctrl not available.\n"; exit 1
fi

# Prepare payload and write last-state
CURRENT_WINDOW_NAME="${MAP_WID_TITLE[$CURRENT_WID]:-unknown}"
TARGET_WINDOW_NAME="${MAP_WID_TITLE[$TARGET_WID]:-unknown}"

TIMESTAMP="$(date +'%Y-%m-%d %H:%M:%S %z')"

payload="$(cat <<EOF
### AC11 Last valid state
TIMESTAMP=${TIMESTAMP}
DESKTOP=${CUR_DESKTOP}
CURRENT_MONITOR=${CUR_MON_IDX}
PREVIOUS_MONITOR=${PREV_MON_IDX}

CURRENT_WID=${CURRENT_WID}
CURRENT_WINDOW_NAME=${CURRENT_WINDOW_NAME}

TARGET_WID=${TARGET_WID}
TARGET_WINDOW_NAME=${TARGET_WINDOW_NAME}
EOF
)"

if write_last_state "$payload"; then
  log "INFO" "Last valid state written to $LAST_STATE_FILE"
else
  log "WARN" "Failed to write last valid state to $LAST_STATE_FILE"
fi

printf "✅ AC11 SUCCESS: Focused first window on monitor %s: %s (Desktop %s).\n" "$PREV_MON_IDX" "$TARGET_WID" "$CUR_DESKTOP"
exit 0