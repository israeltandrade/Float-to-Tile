#!/usr/bin/env bash
# File: 04_Monitor-Area.sh
# Description: Calculates the actual usable screen area for tiling on each monitor,
#              accounting for padding defined in global_config.conf.
# Dependencies: 01_Screen-Resolution.data, global_config.conf.

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# 1. INITIALIZATION & PATHS
# -----------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Define os arquivos usando o caminho raiz robusto
CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_DIR="$ROOT_DIR/Logs"
MONITOR_DATA_FILE="$DATA_DIR/01_Screen-Resolution.data"

# --- FIX 1: Standardize Log File Name (Remove Date Stamp) ---
LOG_FILE="$LOG_DIR/04_Monitor-Area.log"
DATA_FILE="$DATA_DIR/04_Monitor-Area.data"
# --- FIX 2: Define Last Valid State File ---
LAST_VALID_STATE_FILE="$ROOT_DIR/History/04_Monitor-Area.last_valid_state"

TEMP_FINAL_DATA="/tmp/04_monitor_area_$$"

# --- Utility Functions ---
log() {
    # Garante que o diretório de log exista
    mkdir -p "$LOG_DIR"
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}
trap 'rm -f "$TEMP_FINAL_DATA"' EXIT
: > "$LOG_FILE"
log "Module 04 START (Monitor Area Calculation)"

# -----------------------------------------------------------------------------
# 2. LOAD DEPENDENCIES (Config and Monitor Data)
# -----------------------------------------------------------------------------

# Carrega variáveis de configuração (dependência crítica para set -u)
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    log "INFO: Loaded configuration (e.g., GAP_SIZE_PX, PADDING_*_PX)."
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    printf "❌ M04 FAILED: Configuration file not found.\n"
    exit 1
fi

# Carrega a contagem de monitores e variáveis de geometria
if [[ -f "$MONITOR_DATA_FILE" ]]; then
    source "$MONITOR_DATA_FILE"
    log "INFO: Loaded Monitor data (MONITOR_COUNT, MONITOR_N_POS_*)."
else
    log "ERROR: Required data file $MONITOR_DATA_FILE not found. Run M01 first."
    printf "❌ M04 FAILED: Monitor data file not found.\n"
    exit 1
fi

# -----------------------------------------------------------------------------
# 3. CALCULATION LOGIC
# -----------------------------------------------------------------------------

: > "$TEMP_FINAL_DATA"

# Variáveis de Padding (com fallback para 0 se não definidas no config)
PT="${PADDING_TOP_PX:-0}"
PB="${PADDING_BOTTOM_PX:-0}"
PL="${PADDING_LEFT_PX:-0}"
PR="${PADDING_RIGHT_PX:-0}"

# Itera sobre todos os monitores
for ((i = 1; i <= MONITOR_COUNT; i++)); do
    # Obtém a geometria original usando expansão indireta
    X_VAR="MONITOR_${i}_POS_X"; X=${!X_VAR}
    Y_VAR="MONITOR_${i}_POS_Y"; Y=${!Y_VAR}
    W_VAR="MONITOR_${i}_WIDTH"; W=${!W_VAR}
    H_VAR="MONITOR_${i}_HEIGHT"; H=${!H_VAR}
    
    # Calcula a área utilizável (subtraindo o padding)
    NEW_X=$((X + PL))
    NEW_Y=$((Y + PT))
    NEW_W=$((W - PL - PR))
    NEW_H=$((H - PT - PB))

    # Output para o arquivo de dados
    printf "\n# --- USABLE AREA Monitor %s ---\n" "$i" >> "$TEMP_FINAL_DATA"
    printf "USABLE_AREA_%s_X=%s\n" "$i" "$NEW_X" >> "$TEMP_FINAL_DATA"
    printf "USABLE_AREA_%s_Y=%s\n" "$i" "$NEW_Y" >> "$TEMP_FINAL_DATA"
    printf "USABLE_AREA_%s_WIDTH=%s\n" "$i" "$NEW_W" >> "$TEMP_FINAL_DATA"
    printf "USABLE_AREA_%s_HEIGHT=%s\n" "$i" "$NEW_H" >> "$TEMP_FINAL_DATA"
    
    log "INFO: Monitor $i (Usable Area): ${NEW_X},${NEW_Y},${NEW_W}x${NEW_H}"
done

# -----------------------------------------------------------------------------
# 4. OUTPUT GENERATION & STATE PERSISTENCE
# -----------------------------------------------------------------------------

# Escreve o arquivo de dados final (04_Monitor-Area.data)
cat "$TEMP_FINAL_DATA" > "$DATA_FILE"

# --- FIX 3: Persist the valid state ---
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."


# --- Terminal Feedback ---
printf "✅ M04 SUCCESS: Calculated usable area for %s monitor(s).\n" "$MONITOR_COUNT"
log "Module 04 END (SUCCESS)"
exit 0