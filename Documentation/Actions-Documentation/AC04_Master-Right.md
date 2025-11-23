# 🚀 Action Module 04: `AC04_Master-Right.sh`

## 🎯 Objective
This script implements the **Master-Right Layout**, a mirror image of the AC03 module.
It divides the screen into two vertical zones:
1.  **The Master Area (Right):** Occupied by the primary focus window (usually index 0), anchored to the right edge.
2.  **The Stack Area (Left):** A vertical column containing all other windows, occupying the remaining space on the left.

This layout is often preferred by users who read left-to-right and want reference material (the stack) to appear first, or for dual-monitor setups where the primary focus is central.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Safe I/O Architecture** | Uses the same `safe_write` wrappers introduced in v2.6 to prevent crashes during logging or state saving if directory structures are inconsistent. |
| 2 | **Matrix Data Preference** | It prioritizes the abstract layout blueprints from **M07 (`MATRIX_2D`)** if available. If not, it falls back to the linear cycle map from **M06**. |
| 3 | **Master Ratio Enforcement** | Respects the `MASTER_RATIO` variable (default 0.50). Crucially, the Master window's width is calculated first, and the Stack fills the remaining space on the left. |
| 4 | **Geometry Patching (Terminals)** | Includes pixel-perfect adjustments (`-16px` width, `-32px` height) for `xfce4-terminal` to prevent grid-rounding errors. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Safe Writers & Initialization
Standardized safety functions ensuring robust file operations.

```bash
safe_write() {
    local _file=$1; shift
    local _txt="$*"
    mkdir -p "$(dirname "$_file")"
    printf '%s\n' "$_txt" >> "$_file"
}
```

### 2️⃣ Data Refresh & Sourcing
Triggers `run.sh` to refresh the environment state and loads the necessary data files, prioritizing `07_Layout-Matrices.data`.

```bash
if [[ -f "$DATA_DIR/07_Layout-Matrices.data" ]]; then
    source "$DATA_DIR/07_Layout-Matrices.data"
    # Uses MATRIX_2D variables
else
    # Falls back to M06 Cycle Map
fi
```

### 3️⃣ The Layout Logic (Master Right vs. Stack Left)

#### A. The Master Window (Right)
The logic mirrors AC03 but anchors the Master window to the right boundary (`LIMIT_RIGHT`).

```bash
# Calculate Ideal Width based on Ratio
IDEAL_MASTER_W=$(awk ... 'BEGIN{printf "%d", (w - g) * r}')

# Anchor to Right Edge
MASTER_X=$(( LIMIT_RIGHT - ACTUAL_MASTER_W ))

# Apply Geometry
wmctrl -i -r "$MASTER_WID" -e 0,"$MASTER_X","$SAFE_Y","$TARGET_MASTER_W","$TARGET_MASTER_H"
```

#### B. The Stack (Left)
The stack starts at `SAFE_X` (left margin) and fills the width up to the Master window.

```bash
# Calculate Stack Width (Available space to the left of Master)
STACK_START_X=$SAFE_X
STACK_AVAIL_W=$(( MASTER_X - GAPS - SAFE_X ))

# Loop through stack windows
for ((idx=1; idx<COUNT; idx++)); do
    # ... Calculate Y position ...
    # Apply Geometry
    wmctrl -i -r "$WID" -e 0,"$POS_X","$POS_Y","$TARGET_STACK_W","$TARGET_STACK_H"
done
```

### 4️⃣ State Persistence (`AC04_Master-Right.last-valid-state`)

Upon successful layout application, the script saves a snapshot of the arrangement.

**File Location:** `$ROOT_DIR/Actions/Actions_Last-Valid-States/AC04_Master-Right.last-valid-state`

**Format:**
Organized by Desktop and Monitor, listing names and WIDs.

```text
=== DESKTOP 0 (Workspace 1) ===

--- MONITOR 1 (eDP-1-1) ---
# Window Names: Alacritty | Firefox | Libreoffice
# Windows WIDs:
0x02000045: 0x020000bc:
```