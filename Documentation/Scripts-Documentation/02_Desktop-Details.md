# 🖥️ Module 02: Desktop Details (`02_Desktop-Details.sh`)

## 🎯 Objective

To identify the available virtual desktops (workspaces) and determine exactly which one is currently in focus.

**Captured Data:**

1.  **Desktop Count & Names:** How many workspaces exist and their human-readable labels (e.g., "1: Web", "2: Code").
2.  **Active Desktop Index:** A reliable integer representing the currently focused workspace.

---

## 🧠 Logic: Robustness & Fallback Strategies

This module (v1.8) moves away from extracting complex geometry (Work Area) and focuses purely on **identity and focus**. It employs a **Dual-Strategy** to ensure the active desktop is found even if standard tools behave unexpectedly.

### The Active Desktop Hunt

Finding out "where am I?" is harder than it looks on different window managers. The script uses two strategies:

1. **Strategy A (Standard):** Parses `wmctrl -d`. The active desktop is usually marked with an asterisk (`*`).
2. **Strategy B (Fallback):** If the asterisk is missing, it queries the X11 root window property `_NET_CURRENT_DESKTOP` directly using `xprop`.

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Dependency Check & Setup

Since this module relies heavily on `wmctrl`, it performs a pre-flight check to ensure the tool is installed, preventing cascading errors later.

```bash
if ! command -v wmctrl &> /dev/null; then
    log "FAILURE: wmctrl command not found."
    exit 1
fi
```

---

### 2️⃣ Name Extraction (The Parsing Loop)

The script iterates through the output of `wmctrl -d`.
**Raw Line Example:**
`0  * DG: 2880x2700  VP: 0,0  WA: 0,27 2880x2673  1: Web`

The script needs to extract the **Index** (`0`) and the **Name** (`1: Web`), ignoring the geometry data in the middle.

```bash
while read -r line; do
    # Extract the first number (Index)
    desktop_index=$(echo "$line" | awk '{print $1}')

    # Extract the Name using regex anchors
    # Logic: Remove everything up to the "WA:" parameters to isolate the name at the end
    desktop_name=$(echo "$line" | sed 's/.*WA:[^ ]* [^ ]* *//')

    # ... (formatting and saving) ...
done <<< "$WMCTRL_D_OUTPUT"
```

**Why `sed`?**
The position of the name can vary, but the "Work Area" (`WA: ...`) data is always the last technical metric before the name string starts. We use it as a delimiter to cut the line cleanly.

---

### 3️⃣ Determining the Active Desktop (The "Smart" Part)

This is the core robustness feature of v1.8.

```bash
# Strategy A: Look for the '*' marker in wmctrl output
ACTIVE_DESKTOP=$(echo "$WMCTRL_D_OUTPUT" | awk '/\*/ {print $1; exit}')

# Strategy B: If A fails, ask X11 directly via xprop
if [ -z "$ACTIVE_DESKTOP" ]; then
    log "Fallback: '*' marker failed..."
    # Extract value from "_NET_CURRENT_DESKTOP = 1"
    ACTIVE_DESKTOP=$(xprop -root _NET_CURRENT_DESKTOP 2>/dev/null | awk -F'= ' '{print $2}')

    # Sanitize output (remove hex/spaces)
    ACTIVE_DESKTOP=$(echo "$ACTIVE_DESKTOP" | tr -d '[:space:]' | sed 's/0x//g')
fi
```

- **Strategy A** is faster (we already have the `wmctrl` output).
- **Strategy B** is the "source of truth" directly from the X server, useful if `wmctrl` output formatting changes or is buggy.

---

## 📄 Output File: `02_Desktop-Details.data`

The output focuses strictly on workspace context.

| Variable         | Example     | Description                                             |
| :--------------- | :---------- | :------------------------------------------------------ |
| `DESKTOP_COUNT`  | `8`         | Total number of workspaces available.                   |
| `DESKTOP_0_NAME` | `'1: Term'` | Name of the first desktop (index 0).                    |
| `DESKTOP_1_NAME` | `'2: Web'`  | Name of the second desktop (index 1).                   |
| `...`            |             |                                                         |
| `ACTIVE_DESKTOP` | `1`         | The index (0-based) of the currently visible workspace. |

**Note:** Unlike older versions that used `DESKTOP_0_ACTIVE=true`, this version uses a single integer `ACTIVE_DESKTOP=1` for easier comparison in logic scripts.