# ⚙️ Global Configuration Module: `global_config.conf`

## 🎯 Objective
This file holds all the **global settings** that define the core behavior of the Float-to-Tile window management system, including the operation mode, default layout, and exception rules.

It is sourced early by most data processing modules (e.g., **M06**) and is critical for the final layout application module.

---

## 🛠️ Configuration Sections

### 1. ⚙️ Tiling Mode (`TILING_MODE`)
Defines when and how the system attempts to apply tiling layouts to windows.

| Value | Description | Behavior |
| :--- | :--- | :--- |
| `MANUAL` (Default) | On-demand tiling. | Layout is applied **only** when an explicit action command (e.g., a keyboard shortcut) is triggered by the user. |
| `WINDOW_START` | Initial tiling. | Applies the layout when a **new window is created**, but then allows the user to move it freely. |
| `FIXED` | Continuous tiling. | The system constantly monitors and **forces all windows** to conform to the layout, ideal for a pure *tiling window manager* experience. |

---

### 2. 🗺️ Default Layout (`DEFAULT_LAYOUT`)
Defines the initial layout to be applied to any Desktop/Monitor group containing more than one window.

| Value | Description |
| :--- | :--- |
| `TILED` | Dynamic Layout (Chooses 2D or 3D based on Master/Stack logic). |
| `MASTER_LEFT` | 2D Layout: Master window on the left, Stack on the right. |
| `MASTER_RIGHT` | 2D Layout: Master window on the right, Stack on the left. |
| `MONOCLE` | Only the Master window is visible (others are hidden/stacked). |
| `FLOATING` | Disables tiling for this area, leaving windows free. |

---

### 3. 📐 Gaps and Padding (Pixels)
Defines the visual spacing between windows and the screen edge.

| Variable | Usage | Default Example |
| :--- | :--- | :--- |
| `GAP_SIZE_PX` | Space between tiled windows. | `10` |
| `PADDING_TOP_PX` | Top margin of the screen (for panels/bars). | `54` |
| `PADDING_BOTTOM_PX` | Bottom margin of the screen (for docks). | `54` |
| `PADDING_LEFT_PX` | Left screen margin. | `9` |
| `PADDING_RIGHT_PX` | Right screen margin. | `9` |

---

### 4. 🗃️ Floating Window Rules (Exceptions)
A list of windows that the system should **never attempt** to tile, forcing them to remain floating. These rules are read by **Module 05**.

| Variable | Match Type | Example Usage |
| :--- | :--- | :--- |
| `FLOAT_CLASSES` | Application **Class** (Usually the software's name). | `Gimp,Lxappearance` |
| `FLOAT_RESOURCES` | Window **Resource/Instance** (Often used for specific helper or dialog windows). | `Galculator,ColorPicker` |

> ℹ️ **Tip:** Use the command `wmctrl -x -l` in the terminal to identify the *Class* and *Resource* of any open window.

---

### 5. 🔄 Window Cycle Order (`WINDOW_CYCLE_ORDER`)
Defines how **Module 06** must order the windows within a group. This order is used for navigation (`Alt+Tab`) and for mapping the layout matrices.

| Value | Sorting Logic | Effect |
| :--- | :--- | :--- |
| `RAW` | Native listing order from the X Server (Fast, but non-logical). | Deterministic. |
| `TIMESTAMP` | By the time of the last user interaction (`_NET_WM_USER_TIME`). | **Most Recent First** (Classic Alt+Tab Behavior). |
| `INVERTED_TIMESTAMP`| By the time of the last user interaction. | **Least Recent First**. |
| `ALPHABETICAL_ASC` | By Window Title (A-Z). | Ascending Alphabetical Order. |
| `ALPHABETICAL_DESC` | By Window Title (Z-A). | Descending Alphabetical Order. |