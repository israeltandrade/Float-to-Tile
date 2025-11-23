# 🚀 Action Module 07: `AC07_Toggle-Float.sh`

## 🎯 Objective
This script allows the user to toggle a specific window between two states:
1.  **Floating:** The window is removed from the tiling grid, resized to 80% of the monitor, centered, and added to the exclusion list.
2.  **Tiled:** The window is re-added to the tiling grid, and its previous "tiled geometry" (position and size) is restored if saved.

This is essential for temporarily maximizing a window for focus or handling dialogs that were accidentally tiled.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Context Awareness** | Automatically detects the currently focused window (`_NET_ACTIVE_WINDOW`) using `xprop` (with `xdotool` fallback). |
| 2 | **State Persistence (Restore)** | When a window is floated, its **original tiled geometry** is saved to `AC07_Toggle-Float.last-valid-state`. When toggled back, it restores exactly where it was, rather than re-tiling everything. |
| 3 | **Dynamic Exclusion List** | It modifies `Data/05_Floating-WIDs.data` on the fly. Toggling a window updates the system-wide exclusion list immediately, affecting all subsequent tiling operations. |
| 4 | **Smart Centering** | When floating a window, it calculates a pleasing "center stage" geometry (80% of `USABLE_AREA`, centered) rather than placing it randomly. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Active Window Detection
The script must first know *what* to toggle. It tries `xprop` first for speed, then falls back to `xdotool`.

```bash
# Get Active WID
ACTIVE_WID_RAW=$(xprop -root _NET_ACTIVE_WINDOW ...)
if [[ -z ... ]]; then
    # Fallback
    XDOT_DEC=$(xdotool getwindowfocus ...)
fi
# Convert to canonical hex (0x...)
ACTIVE_WID_CAN=$(printf '0x%x' "$ACTIVE_WID_DEC")
```

### 2️⃣ Logic Branch: Float vs. Tile
The script checks if the active window is already in the `FLOAT_WID_LIST`.

#### A. Transitioning to FLOATING
1.  **Save Geometry:** Captures the current X, Y, W, H from the window list.
2.  **Persist State:** appends a structured block to `AC07_Toggle-Float.last-valid-state`.
3.  **Update Exclusion List:** Adds the WID to `05_Floating-WIDs.data`.
4.  **Apply Float Geometry:** Resizes the window to 80% of the screen and centers it.

```bash
# Calculate 80% Center
FLOAT_W=$((W_AREA * 8 / 10))
FLOAT_H=$((H_AREA * 8 / 10))
FLOAT_X=$((X_AREA + (W_AREA - FLOAT_W) / 2))
FLOAT_Y=$((Y_AREA + (H_AREA - FLOAT_H) / 2))

# Apply
wmctrl -i -r "$ACTIVE_WID_CAN" -e 0,"$FLOAT_X","$FLOAT_Y","$FLOAT_W","$FLOAT_H"
```

#### B. Transitioning to TILED
1.  **Remove Exclusion:** Removes the WID from `05_Floating-WIDs.data`.
2.  **Lookup Geometry:** Searches `AC07_Toggle-Float.last-valid-state` for the saved `WID_..._X/Y/W/H` values.
3.  **Restore:** If found, applies the old geometry.
4.  **Fallback:** If no state is found, it triggers `AC01_Tile-Vertical.sh` to re-tile the desktop automatically.

```bash
if $RESTORE_GEOMETRY_FOUND; then
    wmctrl -i -r "$ACTIVE_WID_CAN" -e 0,"$RESTORE_X","$RESTORE_Y","$RESTORE_W","$RESTORE_H"
else
    # Fallback
    "$ROOT_DIR/Actions/AC01_Tile-Vertical.sh"
fi
```

### 3️⃣ State Persistence (`AC07_Toggle-Float.last-valid-state`)

Stores the geometry of windows *before* they become floating.

**Format:**
Explicit variable assignments for easy sourcing/parsing.

```text
# --- WINDOW 0x1200004 ---
WID_0x1200004_X=0
WID_0x1200004_Y=45
WID_0x1200004_W=2880
WID_0x1200004_H=1525
```