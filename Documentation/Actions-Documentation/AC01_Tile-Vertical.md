# 🚀 Action Module 01: `AC01_Tile-Vertical.sh`

## 🎯 Objective
This script implements the **Vertical Tiling** action, where all currently tileable windows on the active desktop/monitor are arranged side-by-side, sharing the available horizontal space equally.

This module is designed to be called explicitly by the user (e.g., via a keyboard shortcut) and includes advanced logic for handling minimum window size requirements and specific application compatibility fixes.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Data Dependency Check** | **MANDATORY:** Always executes `run.sh` first to ensure all geometry and window list data is up-to-date. Aborts immediately if `run.sh` fails. |
| 2 | **Min-Width Detection** | Checks if the calculated standard tile width is **less than** the maximum required `MIN_WIDTH` among the group's windows. |
| 3 | **Overlap Mode (Fallback)** | If minimum width cannot be met, the tiling mode switches to **Overlap**. Windows are stacked with a small horizontal offset, ensuring the minimum width constraint is respected. |
| 4 | **Terminal Fix (Patch)** | Includes a specific adjustment for `xfce4-terminal` windows to prevent rounding issues in grid sizing that can cause the window to extend beyond the monitor boundaries. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Initialization and Configuration
Sets up essential paths, including the new `Actions_Last-Valid-States` directory, and loads the `global_config.conf` file.

```bash
# Define paths for root, data, logs, and last-valid-state
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
# ...
# Guarantee directories exist
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$LAST_STATE_DIR"

# Source global_config.conf
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
# ... (Error handling if config is missing)
```

### 2️⃣ Environment Update (Critical Step)
This is the **most crucial** part of any action script, ensuring the data used for geometry calculations is fresh.

```bash
log "INFO: Updating environment data via run.sh..."

if ! "$ROOT_DIR/run.sh"; then
    log "ERROR: run.sh failed (exit code non-zero). Aborting tiling to prevent errors."
    exit 1
fi
```

### 3️⃣ Data Loading and Mapping
Loads necessary data files (`01`, `02`, `03`, `04`, `06`) and builds associative arrays (maps) for quick lookups of **Min-Width**, **Class**, and **Title** using the Window ID (WID) as the key.

```bash
# Loads: $WINDOW_COUNT, $MONITOR_COUNT, $ACTIVE_DESKTOP, etc.
# Builds:
declare -A MAP_WID_MIN_WIDTH
declare -A MAP_WID_CLASS
declare -A MAP_WID_TITLE
# ...
```

### 4️⃣ Window Processing Loop (Per Monitor)
Iterates through all monitors, checking the window cycle list (`D{DESK}_M{MON}_CYCLE_LIST`) to identify tileable windows for the current desktop.

```bash
# Iterate through all available monitors
for MONITOR_ID in $(seq 1 "${MONITOR_COUNT}"); do
    KEY="D${CURRENT_DESKTOP_ID}_M${MONITOR_ID}"
    WID_LIST_VAR="${KEY}_CYCLE_LIST"
    WID_LIST="${!WID_LIST_VAR:-}"

    if [ -z "$WID_LIST" ]; then continue; fi

    # Get usable area dimensions (X_AREA, Y_AREA, W_AREA, H_AREA)
    # ...
```

### 5️⃣ Tiling vs. Overlap Decision

Before resizing, the script determines the required horizontal space and compares it to the available space to decide the mode of operation.

| Condition | Calculation | Mode |
| :--- | :--- | :--- |
| **Minimum Width Check** | `STANDARD_TILE_WIDTH` < `GROUP_MAX_MIN_WIDTH` | `OVERLAP` |
| **Default Tiling** | `STANDARD_TILE_WIDTH` >= `GROUP_MAX_MIN_WIDTH` | `TILED` |

#### A. `TILED` Mode
Divides the total width equally among all windows, distributes the remainder pixels (`REMAINDER_WIDTH`) one by one, and applies the `GAP_SIZE_PX` configuration.

#### B. `OVERLAP` Mode
Assigns the maximum required `MIN_WIDTH` (`TARGET_W`) to every window. It then calculates the horizontal *step* (`STEP_PX`) needed to offset the windows, ensuring they stack beautifully while maintaining their minimum size requirement.

```bash
# Logic excerpt for Overlap positioning:
if [ "$NUM_WINDOWS" -gt 1 ]; then
    STEP_PX=$(( SLACK_SPACE / (NUM_WINDOWS - 1) )) # Calculate offset
else
    STEP_PX=0
fi
CURRENT_X=$((X_AREA + GAP_SIZE_PX))
# Loop applies TARGET_W and increments CURRENT_X by STEP_PX
```

### 6️⃣ State Persistence (`AC01_Tile-Vertical.last-valid-state`)

Upon successful tiling, the script generates a simple, human-readable file summarizing which windows were organized on which monitor/desktop.

**File Location:** `$ROOT_DIR/Actions/Actions_Last-Valid-States/AC01_Tile-Vertical.last-valid-state`

**Format Example:**
The output includes the active desktop name, monitor name, and a list of the window titles and WIDs that were just tiled.

```markdown
=== DESKTOP 1 (Workspace 1) ===

--- MONITOR 1 (eDP-1-1) ---
# Window Names: Terminal | Code Editor | Documentation
# Windows WIDs:
0x04e00003: 0x04e0001a: 0x0520002f:

--- MONITOR 2 (HDMI-0) ---
# Window Names: Browser
# Windows WIDs:
0x02800010:
```