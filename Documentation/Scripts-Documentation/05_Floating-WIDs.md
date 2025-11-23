# 🧩 Module 05: Floating Window Filter (`05_Floating-WIDs.sh`)

## 🎯 Objective
To act as the "Gatekeeper" for the tiling engine. This module scans the list of active windows and identifies which ones should be **excluded from tiling** (remain floating).

It compares every active window against user-defined rules (Classes and Resources) specified in `global_config.conf`. If a window matches, its ID (WID) is added to a persistent exclusion list.

---

## 🧠 Logic: The Filtering Process

The script performs a **Negative Selection** process:

1. **Ingestion:** It loads the active window list from `03_Window-List.data`.
2. **Rule Parsing:** It reads comma-separated lists from the config file:
    * `FLOAT_CLASSES`: e.g., `"Gimp,Galculator,Oblogout"`
    * `FLOAT_RESOURCES`: e.g., `"dialog,modal,task_dialog"`
3. **Evaluation:** For every window `N`:
    * It checks if the window's `CLASS` contains any string from `FLOAT_CLASSES`.
    * If not, it checks if the `RESOURCE` contains any string from `FLOAT_RESOURCES`.
4. **Verdict:** If a match is found, the Window ID (`WID`) is saved to the `FLOAT_WID_LIST`.

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Safe Data Sourcing (The Security Guard)
Loading external data files using `source` can be risky if the file contains malformed code. This script uses a strict regex filter to ensure it only loads valid variable assignments.

```bash
# Only allow lines starting with WINDOW_... to be sourced
grep -E '^(WINDOW_COUNT=|WINDOW_[0-9]+_[A-Z_]+=)' "$WINDOW_DATA_FILE" > "$TEMP_FILTERED_DATA"
source "$TEMP_FILTERED_DATA"
```

### 2️⃣ Config Parsing with IFS
Bash treats spaces as separators by default. To correctly parse comma-separated lists from the config file (e.g., `App Name, Another App`), the script temporarily changes the `IFS` (Internal Field Separator).

```bash
OLD_IFS=$IFS
IFS=','
read -ra FLOAT_CLASS_LIST <<< "${FLOAT_CLASSES:-}"
# ...
IFS=$OLD_IFS
```

### 3️⃣ Indirect Expansion Loop
Since the number of windows is dynamic, the script uses Bash **indirect expansion** (`${!VAR}`) to read variables like `WINDOW_1_CLASS`, `WINDOW_2_CLASS`, etc., inside the loop.

```bash
for ((i = 1; i <= WINDOW_COUNT; i++)); do
    WINDOW_CLASS_VAR="WINDOW_${i}_CLASS"
    
    # The '!' triggers indirect expansion (get value of the variable named in variable)
    CLASS=${!WINDOW_CLASS_VAR}
    
    # Check for substring match (*$fc*)
    if [[ "$CLASS" == *"$fc"* ]]; then
        SHOULD_FLOAT="true"
    fi
done
```

---

## 📄 Output Data & Logs

### Output File: `05_Floating-WIDs.data`
This file simply lists the IDs of windows that the tiling engine must ignore.

| Variable | Example | Description |
| :--- | :--- | :--- |
| `FLOAT_WID_COUNT` | `2` | Number of windows identified as floating. |
| `FLOAT_WID_LIST` | `0x03400199,0x05e00004` | Comma-separated list of Hex IDs. |

### Log Example (`05_Floating-WIDs.log`)
A record of the decision-making process.

```text
Module 05 START (Floating Window Filter)
INFO: Loaded configuration (FLOAT_CLASSES, FLOAT_RESOURCES).
INFO: Loaded window list data from /home/user/.../Data/03_Window-List.data (filtered safely).
DEBUG: Floating Classes configured:
DEBUG: Floating Resources configured: Galculator,ColorPicker Data state successfully backed up to /home/user/.../Last-Valid-States/05_Floating-WIDs.last_valid_state.
INFO: Total windows to ignore (floating): 0
INFO: FLOAT_WID_LIST:
Module 05 END (SUCCESS)
```