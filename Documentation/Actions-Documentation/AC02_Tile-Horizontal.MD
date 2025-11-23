# 🚀 Action Module 02: `AC02_Tile-Horizontal.sh`

## 🎯 Objective
This script executes the **Horizontal Tiling** action. It organizes all tileable windows on the active desktop/monitor into **rows**, distributing the available **vertical space** equally.

Like its counterpart `AC01`, this module is designed for explicit user invocation (e.g., a shortcut) and features built-in logic to handle minimum vertical size constraints and ensure application compatibility.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Min-Height Check** | Checks if the calculated standard tile height is **less than** the maximum required `MIN_HEIGHT` among the group's windows. This is the inverse of the `AC01` logic. |
| 2 | **Vertical Overlap (Decking)** | If minimum height cannot be met, the tiling mode switches to **Overlap**. Windows are stacked vertically (like a deck of cards) with a small vertical offset, ensuring the minimum height constraint is respected. |
| 3 | **Terminal Fix (Vertical)** | Includes a specific adjustment for `xfce4-terminal` windows to compensate for its internal grid system and prevent height issues when tiling into rows. |
| 4 | **Data Integrity** | Aborts execution immediately if the prerequisite `run.sh` fails, ensuring no tiling action uses outdated or corrupted data. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Data Loading and Constraint Mapping
Similar to `AC01`, all necessary data files are sourced. However, this script specifically maps the **minimum height** property.

```bash
# Loads: 01_Screen-Resolution.data, 06_Window-Cycle-Map.data, etc.
# Builds:
declare -A MAP_WID_MIN_HEIGHT # Key map for vertical constraints
declare -A MAP_WID_CLASS
declare -A MAP_WID_TITLE
# ...
```

### 2️⃣ Window Processing and Max Min-Height Determination
The script iterates through the cycle list for the active monitor and calculates the most restrictive vertical size constraint in the group (`GROUP_MAX_MIN_HEIGHT`).

```bash
# Logic: Determine Constraints (Max Min Height)
GROUP_MAX_MIN_HEIGHT=0
for wid in "${WIDS_ARRAY[@]}"; do
    MW="${MAP_WID_MIN_HEIGHT[$wid]:-100}" # Default 100px
    if [ "$MW" -gt "$GROUP_MAX_MIN_HEIGHT" ]; then
        GROUP_MAX_MIN_HEIGHT=$MW
    fi
done
```

### 3️⃣ Tiling vs. Overlap Decision

The core geometry logic compares the available vertical space (`STANDARD_TILE_HEIGHT`) against the required minimum height (`GROUP_MAX_MIN_HEIGHT`).

| Condition | Calculation | Mode |
| :--- | :--- | :--- |
| **Minimum Height Check** | `STANDARD_TILE_HEIGHT` < `GROUP_MAX_MIN_HEIGHT` | `OVERLAP` |
| **Default Tiling** | `STANDARD_TILE_HEIGHT` >= `GROUP_MAX_MIN_HEIGHT` | `TILED` |

#### A. `TILED` Mode (Row Split)
The total usable height is split equally. Remainder pixels are distributed to the top rows (`REMAINDER_HEIGHT`). **Gaps** are applied only to the top window (`idx = 0`) and the bottom window (`idx = NUM_WINDOWS - 1`) to ensure the gaps align with the outside padding.

```bash
# Example logic for the first row (idx = 0):
# Shift down by GAP_SIZE_PX and reduce window height by GAP_SIZE_PX
if [ "$idx" -eq 0 ]; then
    WINDOW_Y=$((WINDOW_Y + GAP_SIZE_PX))
    WINDOW_H=$((WINDOW_H - GAP_SIZE_PX))
fi
```

#### B. `OVERLAP` Mode (Vertical Decking)
All windows are given the fixed `TARGET_H` height. The horizontal position remains constant, and the vertical position (`CURRENT_Y`) is incremented by a calculated step (`STEP_PX`).

```bash
# Logic excerpt for Overlap positioning:
SLACK_SPACE=$(( SAFE_MAX_H - TARGET_H ))
# ...
STEP_PX=$(( SLACK_SPACE / (NUM_WINDOWS - 1) )) # Vertical offset step
# ...
WINDOW_Y=$CURRENT_Y # Top of the current window
CURRENT_Y=$((CURRENT_Y + STEP_PX)) # Prepare Y for the next window
```

### 4️⃣ State Persistence (`AC02_Tile-Horizontal.last-valid-state`)

Upon successful execution, a status file is saved to the `Actions_Last-Valid-States` directory. This file records the active desktop, the tiled monitors, and the specific **window cycle order** used for the action, ensuring auditability.

**File Location:** `$ROOT_DIR/Actions/Actions_Last-Valid-States/AC02_Tile-Horizontal.last-valid-state`

**Format:** Same human-readable structure as `AC01`, organized by Desktop and Monitor.