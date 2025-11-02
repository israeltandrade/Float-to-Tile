# 🖥️ Module 02: Desktop Details (`02_Desktop-Details.sh`)

## 🎯 Objective
Extract crucial details about virtual desktops (workspaces) in the X-Window environment using `wmctrl -d`.  
This module provides key contextual data for subsequent modules, such as **Module 03 (Window List)**.

---

## 🧠 Logic: Data Extraction and Work Area Analysis
This module processes the verbose output of `wmctrl -d` using **AWK** to robustly extract all necessary geometry fields, including the **Work Area (WA)** dimensions and coordinates.

### Key Data Extracted:
- **Desktop Index and Active Status:** Which desktop is currently in focus.  
- **Work Area (WA) Geometry:** The usable area of the desktop, excluding panels or docks (e.g., `WA: 0,1666 2880x988`).  
- **Visual Name/Icon:** The human-readable name of the desktop (e.g., `"Web"` or `"1: "`).

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Setup, Path Configuration, and Cleanup
Paths are configured to point to the correct directories using the project’s root:

```bash
ROOT_DIR="$(dirname "$(dirname "$0")")"
LOG_FILE="$ROOT_DIR/Logs/02_Desktop-Details.log"
DATA_FILE="$ROOT_DIR/Data/02_Desktop-Details.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/02_Desktop-Details.last_valid_state"

# Temporary files are stored in /tmp/ for cleanup on exit
TEMP_WMCTRL_FILE="/tmp/wmctrl_desktop_$$"
TEMP_FINAL_DATA="/tmp/desktop_data_$$"
```

---

### 2️⃣ Data Acquisition and AWK Parsing
The module executes `wmctrl -d` and pipes the output directly to a multi-line **AWK** script for parsing.

```bash
# Data Acquisition
if ! wmctrl -d > "$TEMP_WMCTRL_FILE"; then
    # ... handle failure and exit ...
fi

# AWK Logic: Splits fields 8 (WA Coords) and 9 (WA Dimensions)
awk '
{
    # ... logic to extract Work Area X/Y and Width/Height ...
    split(wa_coords_field, wa_coords, ",");
    split(wa_wh_str, wa_dim, "x");

    # ... generates shell variables output ...
}
' "$TEMP_WMCTRL_FILE" > "$TEMP_FINAL_DATA"
```

---

### 3️⃣ Output Generation and Persistence
After parsing, the script calculates the total `DESKTOP_COUNT` and generates the final output file, ensuring the valid state is backed up.

```bash
# Calculate count and write to data file
DESKTOP_COUNT=$(wc -l < "$TEMP_WMCTRL_FILE")
printf "DESKTOP_COUNT=%s\n" "$DESKTOP_COUNT" > "$DATA_FILE"

# Append parsed desktop data
cat "$TEMP_FINAL_DATA" >> "$DATA_FILE"

# Valid State Persistence
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
```

---

## 📄 Output File: `02_Desktop-Details.data`
The output file stores shell variables for easy sourcing by other modules.

| Variable | Example | Description |
|-----------|----------|-------------|
| `DESKTOP_COUNT` | `4` | Total number of virtual desktops. |
| `DESKTOP_0_ACTIVE` | `true` | Boolean status indicating if this desktop is currently active. |
| `DESKTOP_0_NAME` | `1: ` | The descriptive name of desktop 0, including the visual index. |
| `DESKTOP_0_WORK_AREA_X` | `0` | X-coordinate of the usable Work Area (WA). |
| `DESKTOP_0_WORK_AREA_WIDTH` | `1920` | Width of the usable Work Area (WA). |