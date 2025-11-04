# 🧩 Módulo 05: `05_Floating-WIDs.sh`

## 🎯 Objetivo  
Identificar e registrar as coordenadas e dimensões das janelas (WIDs) que não devem ser gerenciadas pelo algoritmo de tiling, mas sim mantidas no estado flutuante (*floating*).

## ⚙️ Processo  
O script recebe ou detecta uma lista de Janelas Flutuantes (WIDs) e calcula a geometria ideal (posição e tamanho) para elas, centralizando-as ou posicionando-as de acordo com regras predefinidas dentro da área utilizável do monitor (calculada no **Módulo 04**).  

Este módulo garante que janelas como caixas de diálogo, notificações ou aplicativos específicos permaneçam visíveis e não sejam redimensionadas.

---

## 🔗 Dependências  

| Arquivo | Uso |
|----------|-----|
| `global_config.conf` | Pode ser utilizado para definir regras de tamanho padrão para janelas flutuantes específicas, ou para configurar o ponto de centralização. |
| `Data/04_Monitor-Area.data` | Necessário para obter as coordenadas e dimensões da área utilizável (`USABLE_AREA_N_*`) e garantir que a janela flutuante seja posicionada corretamente dentro dessa área. |
| **Input de WIDs Flutuantes** | O script depende de uma fonte externa (ex: um arquivo de lista ou uma função de detecção) para saber quais WIDs devem ser tratados como flutuantes. |

---

## 🧠 Lógica de Cálculo  

Para cada **WID** identificado como flutuante, o script define um estado de geometria fixa.

| Etapa | Descrição |
|-------|------------|
| **Definir Geometria Desejada (W, H)** | Pode ser um valor fixo (`800x600`), um percentual da área utilizável ou a geometria original da janela. |
| **Calcular Posição (X, Y)** | Geralmente, calcula-se o centro da área utilizável (`USABLE_AREA_N_*`) e subtrai-se metade das dimensões da janela flutuante para centralizá-la. |
| **Registro** | Armazena o `WID` e a geometria forçada (`X`, `Y`, `W`, `H`). |

---

## 📤 Dados de Saída  

**Arquivo:** `Data/05_Floating-WIDs.data`  
Este arquivo lista, linha por linha, todas as janelas que devem ter sua geometria forçada para o estado flutuante.

| Variável | Formato | Descrição |
|-----------|----------|------------|
| `FLOATING_WID_N` | `WID;X;Y;W;H` | Contém o Window ID, seguido das coordenadas `X`, `Y`, Largura (`W`) e Altura (`H`) forçadas, separadas por ponto e vírgula. |

**Exemplo de Conteúdo:**
```
FLOATING_WID_1=0x300000a;560;240;800;600
FLOATING_WID_2=0x1a00000f;1200;100;400;300