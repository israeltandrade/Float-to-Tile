# 🚀 Action Module 09: `AC09_Focus-Prev-Window.sh`

## 🎯 Objective
This script implements the **Reverse Focus Cycle Action**. It switches focus to the "previous" window in the current group (Desktop + Monitor) based on the deterministic order defined in **M06**.

While `AC08` moves forward ($Index + 1$), this module moves backward ($Index - 1$), allowing bi-directional navigation through the tiling stack. It respects the specific sorting criteria (e.g., Alphabetical, Timestamp) configured in `global_config.conf`.

---

## 🛠️ Key Features and Logic

| # | Feature | Detail |
| :--- | :--- | :--- |
| 1 | **Reverse Cycling Math** | Uses safe modulo arithmetic to handle the "wrap-around" case. When at the first window (Index 0), it correctly wraps to the last window in the list. |
| 2 | **Context Awareness** | Like AC08, it identifies the active group (`D{N}_M{N}`) and limits cycling to windows within that specific context, preventing accidental jumps to other monitors. |
| 3 | **WID Normalization** | Includes robust helper functions (`normalize_wid`) to ensure that Window IDs from different sources (`xdotool`, environment variables, data files) match correctly regardless of hex/decimal formatting. |
| 4 | **Atomic State Writing** | Uses temporary files and `mv` to ensure the `last-valid-state` file is never read in a corrupted or partial state by other processes. |

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Active Window Identification
Determines the starting point for the cycle.

```bash
# 1. Try environment variable
# 2. Fallback to xdotool
if [[ "$CURRENT_WID" == "0x0" ]]; then
    XD_DEC="$(xdotool getwindowfocus ...)"
    CURRENT_WID="$(normalize_wid "$XD_DEC")"
fi
```

### 2️⃣ Group Lookup
Scans the cycle maps from **M06** to find where the current window lives.

```bash
find_current_wid_group() {
  # Iterates through _CYCLE_LIST variables
  # Returns FOUND_GROUP_VAR, FOUND_INDEX, and FOUND_CYCLE_ARRAY
}
```

### 3️⃣ The Reverse Cycle Math
This is the core logic difference from AC08. To move backwards safely in a zero-indexed array (where $0 - 1 = -1$), we add the array length before applying the modulo.

**Formula:** $Index_{new} = (Index_{current} - 1 + Length) \% Length$

```bash
LEN=${#FOUND_CYCLE_ARRAY[@]}
PREV_INDEX=$(( (FOUND_INDEX - 1 + LEN) % LEN ))
PREV_WID="${FOUND_CYCLE_ARRAY[$PREV_INDEX]}"
```

### 4️⃣ Focus Execution & Audit
Focuses the target window and records the transition details.

```bash
# Focus
wmctrl -i -a "$PREV_WID"

# Audit
payload="$(cat <<EOF
### AC09 Last valid state
CURRENT_INDEX=${FOUND_INDEX}
PREV_INDEX=${PREV_INDEX}
...
EOF
)"
write_last_state "$payload"
```

---

## 📄 Output File: `AC09_Focus-Prev-Window.last-valid-state`

This file provides a detailed audit trail of the reverse navigation.

```ini
### AC09 Last valid state
TIMESTAMP=2025-11-22 21:42:43 -0300
GROUP=D0_M2
GROUP_DESKTOP=0
GROUP_MONITOR=2

CURRENT_WID=0x1200004
CURRENT_WINDOW_NAME=Alacritty
CURRENT_INDEX=4
...

PREV_WID=0x1400007
PREV_WINDOW_NAME=Firefox
PREV_INDEX=3
...
```