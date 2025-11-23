# 🚀 Action Module 06: `AC06_Monocle.sh`

## 🎯 Objective
This script executes the **Monocle Layout** (also known as "Maximized" or "Fullscreen-like" mode).
It forces **all tileable windows** on the active desktop/monitor to occupy the entire `USABLE_AREA` (Monitor size minus gaps/padding), stacking them perfectly on top of each other.

This layout is ideal for focused tasks where the user wants to see only one window at a time but switch between them quickly using `Alt+Tab`, without the visual distraction of other windows or the taskbar (if configured to cover it).

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Clean & Safe Selection** | Ignores sticky windows (windows visible on all workspaces, typically `DESKTOP == -1`) and floating windows defined in `M05`, ensuring system panels or widgets aren't resized. |
| 2 | **Full Usable Area Usage** | Calculates geometry based on `USABLE_AREA_*` variables (from **M04**), ensuring windows respect the screen padding defined in `global_config.conf` (e.g., leaving space for a polybar). |
| 3 | **Terminal Safety Shrink** | Applies a specific geometry adjustment (`-5px` width, `-40px` height) for `xfce4-terminal` to prevent it from overflowing the screen edges due to internal character grid rounding. |
| 4 | **Focus Preservation** | Optionally attempts to refocus the previously active window after resizing all windows, so the user doesn't lose their place. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Filtered Window Selection
The script iterates through the raw window list to build a `TILE_WIDS_BY_MONITOR` map, applying strict filters.

```bash
# Loop through all windows
if [[ "$DESKTOP" -ne "$ACTIVE_DESK" ]]; then continue; fi
if [[ "$DESKTOP" -eq -1 ]]; then continue; fi # Skip sticky
if [[ -n "$FLOAT_WID_LIST" && ... ]]; then continue; fi # Skip floating

# Add to monitor list
TILE_WIDS_BY_MONITOR[$MONITOR_ID]+=" $WID"
```

### 2️⃣ Geometry Calculation (The "Monocle")
It calculates the target geometry once per monitor (Total Area - Gaps).

```bash
# Calculate Base Geometry
GAPED_X=$((X_AREA + GAP_SIZE_PX))
GAPED_Y=$((Y_AREA + GAP_SIZE_PX))
GAPED_W=$((W_AREA - 2 * GAP_SIZE_PX))
GAPED_H=$((H_AREA - 2 * GAP_SIZE_PX))
```

### 3️⃣ Application Loop
It applies the calculated geometry to **every** window in the list, effectively stacking them.

```bash
for WID in "${WIDS_ARRAY[@]}"; do
    # Remove maximization flags to allow resizing
    wmctrl -i -r "$WID" -b 'remove,maximized_vert,maximized_horz,fullscreen'
    
    # Apply Terminal Fix if needed
    if [[ "$CLASS" == "xfce4-terminal" ]]; then ... fi
    
    # Apply Geometry
    wmctrl -i -r "$WID" -e 0,"$GAPED_X","$GAPED_Y","$TARGET_W","$TARGET_H"
done
```

### 4️⃣ State Persistence (`AC06_Monocle.last-valid-state`)

Upon successful execution, the script saves a snapshot of the arrangement.

**File Location:** `$ROOT_DIR/Actions/Actions_Last-Valid-States/AC06_Monocle.last-valid-state`

**Format:**
Organized by Desktop and Monitor, listing names and WIDs.

```text
=== DESKTOP 0 (Workspace 1) ===

--- MONITOR 1 (eDP-1-1) ---
# Window Names: Firefox | Code
# Windows WIDs:
0x02000045: 0x020000bc:
```