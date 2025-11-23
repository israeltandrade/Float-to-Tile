# 🚀 Action Module 03: `AC03_Master-Left.sh`

## 🎯 Objective
This script implements the classic **Master-Left Layout**.
It divides the screen into two vertical zones:
1.  **The Master Area (Left):** Occupied by the primary focus window (usually index 0).
2.  **The Stack Area (Right):** A vertical column containing all other windows, sharing the remaining height equally.

This module is the primary tiling action for users who want a focused workflow with secondary information visible on the side.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Safe I/O Architecture** | **New in v2.6:** Uses custom `safe_write` wrappers to ensure file operations (logs/states) do not crash the script if directories are missing or permissions are tight. |
| 2 | **Matrix Data Preference** | It prioritizes the abstract layout blueprints from **M07 (`MATRIX_2D`)** if available. If not, it falls back to the linear cycle map from **M06**. |
| 3 | **Master Ratio Enforcement** | Respects the `MASTER_RATIO` variable (default 0.50) from `global_config.conf`, allowing the user to define how much width the Master window consumes. |
| 4 | **Geometry Patching (Terminals)** | specific pixel-perfect adjustments (`-16px` width, `-32px` height) for `xfce4-terminal` to prevent grid-rounding errors from pushing windows off-screen. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Safe Writers & Initialization
The script defines utility functions to handle file appending safely, ensuring the directory tree exists before writing.

```bash
safe_write() {
    local _file=$1; shift
    local _txt="$*"
    mkdir -p "$(dirname "$_file")"
    printf '%s\n' "$_txt" >> "$_file"
}
```

### 2️⃣ Data Refresh & Sourcing
Like all Action modules, it triggers `run.sh` to get the latest state. It then attempts to load the advanced Matrix data.

```bash
if [[ -f "$DATA_DIR/07_Layout-Matrices.data" ]]; then
    source "$DATA_DIR/07_Layout-Matrices.data"
    # Uses MATRIX_2D variables for window ordering
else
    # Falls back to Cycle Map
fi
```

### 3️⃣ The Layout Logic (Master vs. Stack)

#### A. The Master Window (Left)
The script calculates the "Ideal Width" based on the configured ratio and the "Safe Width" (Screen width minus gaps).

```bash
# Calculate 50% (or configured ratio) of safe width
IDEAL_MASTER_W=$(awk -v w="$SAFE_W" -v g="$GAPS" -v r="$MASTER_RATIO" 'BEGIN{printf "%d", (w - g) * r}')

# Apply geometry
wmctrl -i -r "$MASTER_WID" -e 0,"$SAFE_X","$SAFE_Y","$TARGET_MASTER_W","$TARGET_MASTER_H"
```

#### B. The Stack (Right)
If there is more than one window, the script iterates from index 1 to N. It calculates the remaining horizontal space and divides the vertical space equally among the stack windows.

```bash
# Calculate Stack Dimensions
STACK_START_X=$(( SAFE_X + ACTUAL_MASTER_W + GAPS ))
STD_STACK_H=$(( STACK_AVAIL_H / NUM_STACK ))

# Loop through stack windows
for ((idx=1; idx<COUNT; idx++)); do
    # ... Calculate Y position ...
    # Apply Geometry
    wmctrl -i -r "$WID" -e 0,"$POS_X","$POS_Y","$TARGET_STACK_W","$TARGET_STACK_H"
done
```

### 4️⃣ State Persistence (`AC03_Master-Left.last-valid-state`)

Upon successful layout application, the script saves a snapshot of the arrangement.

**File Location:** `$ROOT_DIR/Actions/Actions_Last-Valid-States/AC03_Master-Left.last-valid-state`

**Format:**
Organized by Desktop and Monitor, listing names and WIDs.

```text
=== DESKTOP 0 (Workspace 1) ===

--- MONITOR 2 (HDMI-0) ---
# Window Names: Alacritty | Firefox | Libreoffice
# Windows WIDs:
0x0200004a: 0x0200004d: 0x02000050:
```