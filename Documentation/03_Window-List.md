# 🪟 Module 03: Window List (`03_Window-List.sh`)

## 🎯 Objective
Capture, classify, and structure all active floating window data hierarchically (**Desktop → Monitor → Window**), forming the logical backbone of the window management system.  

This module consumes data from **Module 01 (`01_Screen-Resolution.data`)** and **Module 02 (`02_Desktop-Details.data`)** to ground the window positions to specific monitors and desktops.

---

## 🧠 Functional Steps
The module executes the following sequence:

1. **Data Loading:** Loads monitor geometries and desktop names from the necessary `.data` files.  
2. **Window Capture:** Uses `wmctrl -lxG` to obtain raw geometry, WID, and identification details for all windows.  
3. **AWK Filtering:** Filters out irrelevant windows (e.g., panels, desktops) and normalizes the output fields.  
4. **Monitor Detection (`get_monitor_id`):** Computes each window’s center point and compares it with the loaded monitor geometries to deterministically identify the monitor on which the window resides.  
5. **Deterministic Ordering:** Windows are strictly sorted by `Desktop ID → Monitor ID → Window ID (WID)` for predictable processing.  
6. **Hierarchical Output:** Produces re-indexed, structured output with clear hierarchical headers for each level (**Desktop**, **Monitor**, **Window**).

---

## ⚙️ Robustness Enhancements

### 1️⃣ Shell Safety Configuration
The script employs strict Bash flags to ensure data integrity:

```bash
set -euo pipefail   # Exit on any failure, treat unset vars as errors, fail inside pipes
IFS=$'\n\t'         # Prevents unintended word splitting (handles window titles safely)
```

### 2️⃣ AWK Block Quoting
The AWK logic for initial filtering is passed through a quoted **here-document** (`<<'AWK'`), preventing shell expansion inside the block.  
This guarantees the AWK code remains intact, solving potential formatting issues.

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Setup, Path Configuration, and Cleanup
Paths are configured to point to the correct directories using the project’s root, and dependency files are loaded from the `Data/` directory.

```bash
ROOT_DIR="$(dirname "$(dirname "$0")")"
LOG_FILE="$ROOT_DIR/Logs/03_Window-List.log"
DATA_FILE="$ROOT_DIR/Data/03_Window-List.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/03_Window-List.last_valid_state"

MONITOR_DATA_FILE="$ROOT_DIR/Data/01_Screen-Resolution.data"
DESKTOP_DATA_FILE="$ROOT_DIR/Data/02_Desktop-Details.data"

# ... (Temporary files are stored in /tmp/ for cleanup on exit)
```

---

### 2️⃣ Monitor Detection Function
The core logic to link a window to a physical display:

```bash
get_monitor_id() {
    # ... calculates window center (center_x, center_y) ...
    
    # ... loops through MONITOR_X/Y/W/H arrays ...
    if [ "$center_x" -ge "$m_x" ] && [ "$center_x" -lt "$((m_x + m_w))" ] && \
       [ "$center_y" -ge "$m_y" ] && [ "$center_y" -lt "$((m_y + m_h))" ]; then
        # ... monitor found, returns ID ...
    fi
}
```

---

### 3️⃣ Final Formatting and Header Injection
The script uses a final loop to re-index the deterministically sorted data and inject the necessary hierarchical headers, ensuring a structured output file:

```bash
# Loop through the final, clean data to inject headers
while IFS= read -r line; do
    # 1. Check for DESKTOP field to inject the highest-level header
    if [[ "$line" == WINDOW_?*_DESKTOP=* ]]; then
        # ... logic to print DESKTOP header ...
    
    # 2. Check for MONITOR field to inject the mid-level header
    elif [[ "$line" == WINDOW_?*_MONITOR=* ]]; then
        # ... logic to print MONITOR header ...

    # 3. Check for WID field to inject the lowest-level header
    elif [[ "$line" == WINDOW_?*_WID=* ]]; then
        # ... logic to print WINDOW header and flush buffered lines ...
    fi
done < "$TEMP_FINAL_DATA"
```

---

## 📄 Output File: `03_Window-List.data`
The output file contains a hierarchical, re-indexed list of all windows in the X11 environment.  
It starts with the `WINDOW_COUNT` header followed by per-window blocks:

| Variable | Example | Description |
|-----------|----------|-------------|
| `WINDOW_N_DESKTOP` | `0` | Desktop ID to which the window belongs. |
| `WINDOW_N_MONITOR` | `1` | Monitor ID where the window center is located. |
| `WINDOW_N_WID` | `0x02c00032` | X-Window ID. |
| `WINDOW_N_CLASS` | `Google-chrome` | Application Class. |
| `WINDOW_N_TITLE` | `Gemini - Google Gemini` | Full Window Title. |