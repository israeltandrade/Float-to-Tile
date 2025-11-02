# 🪟 Module 03: Window List (03_Window-List.sh)

## 🎯 Objective  
Capture, classify, and structure window data hierarchically (Desktop → Monitor → Window), forming the logical backbone of the window management system.

## ⚙️ Functionality Overview  

### 🧠 Robustness Enhancements (v5.2 – AWK Formatting Fix, robust)

#### ✅ Robustness Flags (`set -euo pipefail`)  
- **`-e` (errexit):** Script exits immediately on any command failure, preventing partial or inconsistent state.  
- **`-u` (nounset):** Treats unset variables as errors, ensuring safer variable references.  
- **`-o pipefail`:** Ensures that any failed command in a pipeline triggers a failure instead of being masked by later commands.  

#### 🧱 IFS Adjustment (`IFS=$'\n\t'`)  
Sets the **Internal Field Separator** to newline and tab only.  
This prevents unintended word splitting, ensuring that window titles and filenames with spaces are read as a single unit.

#### 🧾 AWK Block Quoting (Here-Document Quoted)  
The AWK logic is passed through a **quoted here-document** (`<<'AWK'`), preventing shell expansion inside the block.  
This guarantees the AWK code is preserved exactly as written, solving prior formatting issues that caused execution errors.

---

## 🔧 Functional Steps  

1. **Data Loading:**  
   Loads data from `01_Screen-Resolution.data` (monitors) and `02_Desktop-Details.data` (desktops).  

2. **Window Capture:**  
   Uses `wmctrl -lxG` to obtain geometry and identification details for all active windows.  

3. **AWK Filtering:**  
   Filters out irrelevant windows (e.g., panels, backgrounds) and normalizes field structure for consistent parsing.  

4. **Monitor Detection (`get_monitor_id`):**  
   Computes each window’s center point and compares it with monitor geometries to determine on which monitor the window resides.  

5. **Deterministic Ordering:**  
   Windows are strictly sorted by **Desktop ID → Monitor ID → Window ID (WID)** for predictable hierarchy and processing order.  

6. **Hierarchical Output:**  
   Produces re-indexed, structured output with clear hierarchical headers for each level:  
   ```
   # ================= DESKTOP ...
   # ------------- Monitor ...
   # --- Window ...
   ```  
   This organization facilitates reading, debugging, and downstream processing by **Module 04**.  

---

## 💾 Output File: `03_Window-List.data`

The output file contains a hierarchical, re-indexed list of all windows in the X11 environment.  
It starts with the `WINDOW_COUNT` header followed by per-window blocks:

| Variável | Exemplo | Descrição |
| :--- | :--- | :--- |
| `WINDOW_N_DESKTOP` | `0` | ID do Desktop ao qual a janela pertence. |
| `WINDOW_N_MONITOR` | `1` | ID do Monitor onde o centro da janela se encontra. |
| `WINDOW_N_WID` | `0x02c00032` | ID da Janela X-Window. |
| `WINDOW_N_CLASS` | `Google-chrome` | Classe da Aplicação. |
| `WINDOW_N_TITLE` | `Gemini - Google Gemini` | Título completo da Janela. |