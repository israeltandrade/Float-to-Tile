# 🚀 Action Module 08: `AC08_Focus-Next-Window.sh`

## 🎯 Objective
This script implements the **Focus Cycle Action**. It intelligently switches focus to the "next" window in the current group (Desktop + Monitor) based on the deterministic order defined in **M06**.

Unlike standard Alt-Tab (which is often history-based or global), this action respects the specific sorting criteria (e.g., Alphabetical, Timestamp, or Raw) configured in `global_config.conf`, ensuring predictable navigation within the tiling context.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Context-Aware Cycling** | Identifies which Monitor and Desktop the currently focused window belongs to, and only cycles through windows in that specific group (`D{N}_M{N}_CYCLE_LIST`). |
| 2 | **Robust WID Normalization** | Handles various Window ID formats (Decimal, Hex with/without `0x`, Padding) to ensure reliable comparisons between different data sources (`xdotool` vs `wmctrl`). |
| 3 | **State Persistence (Audit)** | records a detailed snapshot of the transition (Current Window → Next Window) in `AC08_Focus-Next-Window.last-valid-state`, useful for debugging focus behavior. |
| 4 | **Fallback Mechanisms** | If `xprop` fails to identify the active window, it falls back to `xdotool`. If `wmctrl` fails to focus by Hex ID, it retries with the Decimal ID. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Active Window Identification
The script must determine "Where am I?" (Current WID) before calculating "Where to go?".

```bash
# 1. Try environment variable from run.sh
# 2. Fallback to xdotool if needed
if [[ "$CURRENT_WID" == "0x0" ]]; then
    XD_DEC="$(xdotool getwindowfocus ...)"
    CURRENT_WID="$(normalize_wid "$XD_DEC")"
fi
```

### 2️⃣ Group Lookup & Index Finding
It searches through all cycle lists loaded from **M06** to find which list contains the current window.

```bash
find_current_wid_group() {
  # Iterates through all variables ending in _CYCLE_LIST
  # ...
  if [[ "${tmp_arr[$i]}" == "$CURRENT_WID" ]]; then
      FOUND_GROUP_VAR="$var" # e.g., D0_M1_CYCLE_LIST
      FOUND_INDEX="$i"       # e.g., 2
      return 0
  fi
  # ...
}
```

### 3️⃣ The Cycle Math
Calculates the next index using modulo arithmetic to wrap around to the start of the list.

```bash
# Next Index = (Current + 1) % Total_Count
NEXT_INDEX=$(( (FOUND_INDEX + 1) % ${#FOUND_CYCLE_ARRAY[@]} ))
NEXT_WID="${FOUND_CYCLE_ARRAY[$NEXT_INDEX]}"
```

### 4️⃣ Focus Execution & State Saving
Attempts to focus the target window and writes the detailed state file.

```bash
# Focus
wmctrl -i -a "$NEXT_WID"

# Write State
payload="$(cat <<EOF
### AC08 Last valid state
TIMESTAMP=${TIMESTAMP}
GROUP=${GROUP_KEY}
CURRENT_WID=${CURRENT_WID} ...
NEXT_WID=${NEXT_WID} ...
EOF
)"
write_last_state "$payload"
```

---

## 📄 Output File: `AC08_Focus-Next-Window.last-valid-state`

This file provides a detailed audit trail of the last focus operation.

```ini
### AC08 Last valid state
TIMESTAMP=2025-11-22 21:40:40 -0300
GROUP=D0_M2
GROUP_DESKTOP=0
GROUP_MONITOR=2

CURRENT_WID=0x1200004
CURRENT_WINDOW_NAME=Alacritty
CURRENT_INDEX=4
CURRENT_GEOMETRY_X=19 ...

NEXT_WID=0x200004a
NEXT_WINDOW_NAME=Firefox
NEXT_INDEX=0
NEXT_GEOMETRY_X=19 ...
```