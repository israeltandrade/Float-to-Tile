# 🧩 Módulo 04: `04_Monitor-Area.sh`

## 🎯 Objetivo  
Calcula a área de tela (coordenadas e dimensões) que deve ser considerada a área utilizável para o algoritmo de tiling.  
Esta área é a geometria total do monitor menos o padding global definido no arquivo de configuração.

## ⚙️ Processo  
O script carrega as coordenadas originais do monitor (`X`, `Y`, `W`, `H`) e aplica as subtrações e somas de padding  
para definir a nova área de trabalho para o gerenciador de janelas.

## 🔗 Dependências  

| Arquivo | Uso |
|----------|-----|
| `global_config.conf` | Requer as variáveis de padding (`PADDING_TOP_PX`, `PADDING_BOTTOM_PX`, `PADDING_LEFT_PX`, `PADDING_RIGHT_PX`) para realizar os cálculos de ajuste. |
| `Data/01_Screen-Resolution.data` | Requer o número de monitores (`MONITOR_COUNT`) e a geometria original de cada um (`MONITOR_N_POS_X`, `MONITOR_N_POS_Y`, etc.). |

## 🧠 Lógica de Cálculo  

Para cada monitor `N` detectado, as novas dimensões e posições são calculadas com base nas variáveis de padding:

| Cálculo | Fórmula |
|----------|----------|
| **Nova Posição X** | `X_original + PADDING_LEFT_PX` |
| **Nova Posição Y** | `Y_original + PADDING_TOP_PX` |
| **Nova Largura** | `W_original - PADDING_LEFT_PX - PADDING_RIGHT_PX` |
| **Nova Altura** | `H_original - PADDING_TOP_PX - PADDING_BOTTOM_PX` |

## 📤 Dados de Saída  

**Arquivo:** `Data/04_Monitor-Area.data`  
Este arquivo contém as novas variáveis de geometria para a área utilizável de cada monitor (`N`):

| Variável | Descrição | Exemplo |
|-----------|------------|----------|
| `USABLE_AREA_N_X` | Coordenada X ajustada para o monitor N. | `USABLE_AREA_1_X=10` |
| `USABLE_AREA_N_Y` | Coordenada Y ajustada para o monitor N. | `USABLE_AREA_1_Y=40` |
| `USABLE_AREA_N_WIDTH` | Largura utilizável ajustada para o monitor N. | `USABLE_AREA_1_WIDTH=1900` |
| `USABLE_AREA_N_HEIGHT` | Altura utilizável ajustada para o monitor N. | `USABLE_AREA_1_HEIGHT=1040` |