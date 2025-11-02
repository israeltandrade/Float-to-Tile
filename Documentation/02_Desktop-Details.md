# 🖥️ Module 02: Desktop Details (02_Desktop-Details.sh)

## 🎯 Objective  
Extract crucial details about virtual desktops (workspaces) in the X-Window environment using `wmctrl`.  
This module provides key contextual data for subsequent modules, such as **Module 03 (Window List)**.

## ⚙️ Functionality Overview  

### 🧩 Core Functions  
- **Count and Details:** Uses `wmctrl -d` to obtain desktop IDs, geometry, and total count.  
- **Name Identification:** Attempts to extract descriptive desktop names (if supported by the window manager, e.g., XFCE or GNOME) using `xprop`.  
- **Data Output:** Saves all configuration details into `./02_Desktop-Details.data`.  

---

## 💾 Output File: `02_Desktop-Details.data`  
The output file stores **shell variables** for easy sourcing by other modules.

| Variável | Exemplo | Descrição |
| :--- | :--- | :--- |
| `DESKTOP_COUNT` | `4` | Número total de desktops virtuais. |
| `CURRENT_DESKTOP_ID` | `0` | O ID do desktop atualmente ativo (começa em 0). |
| `DESKTOP_0_NAME` | `1: ` | O nome descritivo do desktop 0, incluindo o índice visual. |
| `DESKTOP_0_POS_X`, `POS_Y` | `0` | Coordenadas X e Y do desktop (usado para geometria). |
| `DESKTOP_0_WIDTH`, `HEIGHT` | `1920` | Largura e Altura do desktop. |

---