#!/usr/bin/env bash
# File: 05_Floating-WIDs.sh
# Description: Identifies Window IDs (WIDs) that should remain floating based on 
#              rules in global_config.conf (FLOAT_CLASSES, FLOAT_RESOURCES).
# Dependencies: 03_Window-List.data, global_config.conf.
# Output: Data/05_Floating-WIDs.data (defines FLOAT_WID_LIST and FLOAT_WID_COUNT)

set -euo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# 1. INITIALIZATION & PATHS
# -----------------------------------------------------------------------------

# Define o caminho raiz subindo um nível a partir do diretório do script (Scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Define os arquivos usando o caminho raiz robusto
CONFIG_FILE="$ROOT_DIR/global_config.conf"
DATA_DIR="$ROOT_DIR/Data"
LOG_DIR="$ROOT_DIR/Logs"
WINDOW_DATA_FILE="$DATA_DIR/03_Window-List.data"

LOG_FILE="$LOG_DIR/05_Floating-WIDs.log"
DATA_FILE="$DATA_DIR/05_Floating-WIDs.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/05_Floating-WIDs.last_valid_state"

# Arquivos temporários
TEMP_FILTERED_DATA="/tmp/05_filtered_data_$$"
TEMP_FINAL_DATA="/tmp/05_temp_final_data_$$" 

# --- UTILITY FUNCTIONS ---
log() {
# ... (existing code ... no changes) ...
    # Garante que o diretório de log exista
    mkdir -p "$LOG_DIR"
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$1" >> "$LOG_FILE"
}

# --- INITIALIZATION & CLEANUP ---
: > "$LOG_FILE"
: > "$TEMP_FINAL_DATA"
# Array para armazenar WIDs que devem ser ignorados pela lógica de tiling.
declare -a FLOATING_WIDS=()

# Função de limpeza: remove temporários em caso de sucesso, mantém em caso de falha.
cleanup() {
# ... (existing code ... no changes) ...
    local exit_code=$?
    rm -f "$TEMP_FINAL_DATA"
    
    if [ "$exit_code" -ne 0 ] && [ -f "$TEMP_FILTERED_DATA" ]; then
        # Se falhou, informa o usuário e mantém o arquivo para inspeção
        # CRITICAL FIX: Added '--' to printf to handle the emoji/string as a literal format.
        printf -- "\n\n⚠️ DIAGNÓSTICO: Módulo 05 FALHOU (Exit Code: %s).\n" "$exit_code"
        printf -- "O arquivo temporário quebrou o 'source' e foi MANTIDO para inspeção.\n"
        printf -- "VERIFIQUE O CONTEÚDO em: %s\n\n" "$TEMP_FILTERED_DATA"
    else
        # Limpa o arquivo problemático em caso de sucesso
        rm -f "$TEMP_FILTERED_DATA"
    fi
}

trap cleanup EXIT
log "Module 05 START (Floating Window Filter)"

# -----------------------------------------------------------------------------
# 2. LOAD CONFIGURATION AND DEPENDENCIES
# -----------------------------------------------------------------------------

# Carrega regras flutuantes de global_config.conf
if [[ -f "$CONFIG_FILE" ]]; then
# ... (existing code ... no changes) ...
    source "$CONFIG_FILE"
    log "INFO: Loaded configuration (FLOAT_CLASSES, FLOAT_RESOURCES)."
else
    log "ERROR: Configuration file not found at $CONFIG_FILE. Exiting."
    printf "❌ M05 FAILED: Configuration file not found.\n"
    exit 1
fi

# Carrega dados da lista de janelas (FILTRO CRÍTICO)
if [[ -f "$WINDOW_DATA_FILE" ]]; then
# ... (existing code ... no changes) ...
    
    # CRÍTICO: Filtra EXCLUSIVAMENTE linhas que são atribuições de variáveis válidas.
    # O 03_Window-List.sh agora usa aspas simples, tornando isso seguro.
    grep -E '^(WINDOW_COUNT=|WINDOW_[0-9]+_[A-Z_]+=)' "$WINDOW_DATA_FILE" > "$TEMP_FILTERED_DATA"

    # Executa o source no arquivo temporário.
    source "$TEMP_FILTERED_DATA"
    log "INFO: Loaded window list data from $WINDOW_DATA_FILE (filtered safely)."
else
# ... (existing code ... no changes) ...
    log "ERROR: Window list data file not found at $WINDOW_DATA_FILE. Exiting."
    printf "❌ M05 FAILED: Missing window list data.\n"
    exit 1
fi

# -----------------------------------------------------------------------------
# 3. FILTERING LOGIC
# -----------------------------------------------------------------------------

# CRITICAL FIX: Remove 'local' keyword from global scope.
# Store the current IFS (Internal Field Separator)
OLD_IFS=$IFS

# Temporarily set IFS to comma for 'read'
IFS=',' 
read -ra FLOAT_CLASS_LIST <<< "${FLOAT_CLASSES:-}"
read -ra FLOAT_RESOURCE_LIST <<< "${FLOAT_RESOURCES:-}"

# Restore the original IFS
IFS=$OLD_IFS

log "DEBUG: Floating Classes configured: ${FLOAT_CLASS_LIST[*]}"
log "DEBUG: Floating Resources configured: ${FLOAT_RESOURCES[*]}"

# Itera sobre todas as janelas detectadas
for ((i = 1; i <= WINDOW_COUNT; i++)); do
# ... (existing code ... no changes) ...
    WINDOW_WID_VAR="WINDOW_${i}_WID"
    WINDOW_CLASS_VAR="WINDOW_${i}_CLASS"
    WINDOW_RESOURCE_VAR="WINDOW_${i}_RESOURCE"
    
    # Usa expansão indireta para obter os valores
    WID=${!WINDOW_WID_VAR}
    
    # CRÍTICO: Agora que o 'source' lidou com o escaping (%q), 
    # as variáveis já estão limpas. Não precisamos mais do 'tr -d'.
    CLASS=${!WINDOW_CLASS_VAR}
    RESOURCE=${!WINDOW_RESOURCE_VAR}
    
    SHOULD_FLOAT="false"

    # Checa contra FLOAT_CLASSES (usa *...* para correspondência parcial)
    for fc in "${FLOAT_CLASS_LIST[@]}"; do
# ... (existing code ... no changes) ...
        if [[ -z "$fc" ]]; then continue; fi 
        if [[ "$CLASS" == *"$fc"* ]]; then
            SHOULD_FLOAT="true"
            log "INFO: Window $WID ($CLASS) marked floating by CLASS rule (Match: $fc)."
            break
        fi
    done
    
    # Checa contra FLOAT_RESOURCES (usa *...* para correspondência parcial)
    if [[ "$SHOULD_FLOAT" == "false" ]]; then
        for fr in "${FLOAT_RESOURCE_LIST[@]}"; do
# ... (existing code ... no changes) ...
            if [[ -z "$fr" ]]; then continue; fi 
            if [[ "$RESOURCE" == *"$fr"* ]]; then
                SHOULD_FLOAT="true"
                log "INFO: Window $WID ($RESOURCE) marked floating by RESOURCE rule (Match: $fr)."
                break
            fi
        done
    fi

    # Adiciona ao array se for flutuante
    if [[ "$SHOULD_FLOAT" == "true" ]]; then
# ... (existing code ... no changes) ...
        FLOATING_WIDS+=("$WID")
    fi
done

# -----------------------------------------------------------------------------
# 4. OUTPUT GENERATION
# -----------------------------------------------------------------------------

FLOAT_WID_COUNT=${#FLOATING_WIDS[@]}
FLOAT_WID_LIST=$(IFS=','; echo "${FLOATING_WIDS[*]}") # Lista separada por vírgulas

printf "FLOAT_WID_COUNT=%s\n" "$FLOAT_WID_COUNT" > "$DATA_FILE"
# Usa aspas simples para proteger a string vazia ou com vírgulas
printf "FLOAT_WID_LIST='%s'\n" "$FLOAT_WID_LIST" >> "$DATA_FILE" 

# --- 5. STATE PERSISTENCE ---
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
log "Data state successfully backed up to $LAST_VALID_STATE_FILE."

log "INFO: Total windows to ignore (floating): $FLOAT_WID_COUNT"
log "INFO: FLOAT_WID_LIST: $FLOAT_WID_LIST"

# --- Terminal Feedback ---
printf "✅ M05 SUCCESS: Identified %s floating window WIDs.\n" "$FLOAT_WID_COUNT"
log "Module 05 END (SUCCESS)"
exit 0