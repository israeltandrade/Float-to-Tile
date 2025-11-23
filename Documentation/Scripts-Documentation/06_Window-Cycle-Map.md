# 🔄 Module 06: Window Cycle Map (`06_Window-Cycle-Map.sh`)

## 🎯 Objective
To act as the **Sorting Hat** of the system.
It takes the raw list of windows (from M03), filters out the floating ones (from M05), and organizes the remaining "Tileable" windows into deterministic, ordered lists grouped by **Desktop** and **Monitor**.

This ordered list is the "Single Source of Truth" for:
1. **Focus Cycling:** Determining which window comes "next" when you press Alt-Tab.
2. **Layout Generation:** Determining which window goes where in the grid (e.g., Window #1 goes to Master, #2 to Stack).

---

## 🧠 Logic: Smart Ordering & Heuristics

The module doesn't just sort; it *interprets* the window data to create a logical flow for the user.

### 1. Sorting Modes (The Strategy)
The sort order is controlled by `WINDOW_CYCLE_ORDER` in `global_config.conf`.

| Mode | Logic | Use Case |
| :--- | :--- | :--- |
| `ALPHABETICAL_ASC` | Sorts A-Z by Title/App Name. | Great for finding windows by name. |
| `TIMESTAMP` | Sorts by Last Active Time (Newest first). | Traditional "Alt-Tab" behavior. |
| `RAW` | Sorts by Window ID. | Deterministic, based on creation order. |

### 2. Title Normalization (The "Smart" Part)
Sorting by raw title is messy (e.g., `[!]  Alert` vs `Alert`). The script uses a robust normalization function:
* **Strips Noise:** Removes punctuation, symbols, and control characters.
* **Transliterates:** Converts Unicode (e.g., `é` → `e`) for ASCII safety.
* **Folds Case:** Treats `Chrome` and `chrome` as identical.

### 3. The "Filename" Heuristic
If a window title looks like a technical filename (e.g., `document_final_v2.pdf` or `192.168.1.5`), the script automatically prioritizes the **Application Name** (Resource) instead.
* *Raw Title:* `2024-11-Report.docx`
* *Sorted As:* `Word` (Resource Name) -> Ensures all Word documents stay grouped together.

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ The Ingestion Phase
It loads all dependencies. Note the special handling for **Monitor Names** which are now read directly from Module 01 to provide context in the output file.

```bash
# Reads MONITOR_N_NAME from 01_Screen-Resolution.data
read_monitor_names
```

### 2️⃣ The Master List Builder
It iterates through every window from Module 03.
1. **Checks Floating Status:** If `IS_FLOATING[WID]` exists, skip.
2. **Calculates Display Name:** Applies the heuristics (Title vs Resource).
3. **Generates Sort Key:** Creates a normalized string for sorting.

```bash
# Heuristic: If title looks like a filename, use App Name (Resource)
if looks_like_filename_or_id "$SIMPLE_TITLE"; then
    WINDOW_DISPLAY_NAME="${RESOURCE:-$CLASS}"
else
    WINDOW_DISPLAY_NAME="$SIMPLE_TITLE"
fi
```

### 3️⃣ The Sort Command
The script constructs a targeted `sort` command. It forces `LC_ALL=C` **only** for the sort operation to ensure identical sorting behavior across different system locales.

```bash
SORT_COMMAND="LC_ALL=C sort -t'|' -k1,1n -k2,2n -k4,4$SORT_FLAG ..."
eval "$SORT_COMMAND"
```
* `-k1,1n`: Primary Sort by Desktop (Numeric).
* `-k2,2n`: Secondary Sort by Monitor (Numeric).
* `-k4,4`: Tertiary Sort by our custom `SORT_KEY`.

### 4️⃣ Output Generation
The script writes the data in a structured format. It includes rich comments for debugging but keeps the variable assignments clean for sourcing.

```bash
# Generates standard variable arrays
D1_M1_CYCLE_LIST='0x03400199 0x03400200'
D1_M1_COUNT=2
```

---

## 📄 Output File: `06_Window-Cycle-Map.data`

This file is organized into blocks for each Desktop/Monitor pair.

| Variable | Example | Description |
| :--- | :--- | :--- |
| `D{N}_M{N}_CYCLE_LIST` | `'0x0A 0x0B'` | Space-separated list of WIDs in their final sorted order. |
| `D{N}_M{N}_COUNT` | `2` | The number of tileable windows in this specific group. |

### Human-Readable Section (Comments)
The file includes a visual map for debugging:

```ini
# ================= DESKTOP 1 (VISUAL INDEX: 2 | NAME: 2: Web) =================
# ------------- MONITOR 2 (HDMI-0) -------------
# --- WINDOW 1 ---
#   NAME=Firefox
# --- WINDOW 2 ---
#   NAME=LibreOffice
```