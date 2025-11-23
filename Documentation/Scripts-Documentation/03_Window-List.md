# 🪟 Module 03: Window List (`03_Window-List.sh`)

## 🎯 Objective
To capture, enrich, and structure the inventory of all active floating windows. This module acts as the "Intelligence Agency" of the system, gathering deep details about every window to enable smart tiling decisions later.

**It bridges the gap between:**
1.  **Logical Space:** Which Desktop (Workspace) the window is on.
2.  **Physical Space:** Which Monitor (Screen) contains the window's center.
3.  **Application Constraints:** Minimum size limits, process age, and user interaction time.

---

## 🧠 Logic: Deep Enrichment & Hierarchy

This is the most complex data-gathering module. It goes beyond a simple list by performing **Deep Enrichment** on every window found:

1. **Robust Geometry Hints (The "Full Dump"):** It captures the `WM_NORMAL_HINTS` (specifically `program specified minimum size`) by dumping all xprop data and parsing it safely. This prevents the tiling engine from crushing windows (like Terminals or Dialogs) below their usable size.
2. **Process Start Time Strategy:** To distinguish between two identical windows (e.g., two "Chrome" windows), it calculates the exact **Process Start Time (Epoch)**. It uses a triple-fallback strategy (`etimes` → `lstart` → `/proc` calculation) to ensure accuracy.
3. **Smart Title Cleaning:** It strips noise from window titles (e.g., turning *"Gemini - Google Chrome"* into *"Gemini"*) and normalizes application names (e.g., *"code"* becomes *"Visual Studio Code"*).
4. **Deterministic Sorting:** Windows are strictly sorted by `Desktop → Monitor → Window ID` and then Re-Indexed (1 to N), ensuring the output is always predictable.

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Dependency Loading & Filtering
The script first loads the "Map" (Monitor Data) and the "Territory" (Desktop Names). It then runs `wmctrl -lxG` to get the raw population.

```bash
# AWK Filter: Removes Panels, Desktop layers, and invalid windows (-1)
awk -f - "$TEMP_WMCTRL_FILE" > "$TEMP_UNSORTED_FILE" <<'AWK'
! /xfce4-panel|xfdesktop/ && $2 != "-1" {
    # ... extracts WID, DESKTOP, POS, SIZE, CLASS ...
}
AWK
```

---

### 2️⃣ The Enrichment Loop (The Heavy Lifter)
The script iterates through every raw window to fetch expensive data.

#### A. The "Full Dump" Hint Extraction
Older versions failed to parse dimensions like `750 86` correctly due to global `IFS` settings. v1.9.6 fixes this:

```bash
# 1. Dump all properties once (Faster/Safer)
FULL_XPROP=$(timeout 1s xprop -id "$WID" 2>/dev/null)

# 2. Grep for size hints safely
HINT_LINE=$(echo "$FULL_XPROP" | grep "program specified minimum size" || true)

# 3. IFS Fix: Locally change Internal Field Separator to space to read "750 86"
if [ -n "$VALS" ]; then
    IFS=' ' read -r MIN_W MIN_H <<< "$VALS"
fi
```

#### B. Process Start Time (Identity Fingerprinting)
Knowing *when* a window started helps in "History Navigation" (e.g., Alt-Tab behavior).

```bash
# Strategy 1: 'ps -o etimes' (Elapsed seconds). Most accurate.
# Strategy 2: 'ps -o lstart' (Human date). Parsed via 'date -d'.
# Strategy 3: '/proc/UPTIME' vs '/proc/PID/stat'. Low-level fallback.
```

#### C. Monitor Detection (Center of Gravity)
A window belongs to the monitor that contains its center point.

```bash
get_monitor_id() {
    local center_x=$((win_x + win_w / 2))
    # ... loops through monitors to find which bounds contain center_x/y ...
}
```

---

### 3️⃣ Output Generation & Structuring
Finally, the script sorts the data and generates a **Hierarchical Data File**. It injects visual headers (`# === DESKTOP ===`, `# --- WINDOW ---`) to make the file human-readable and easy to debug.

```bash
# Output Structure:
# 1. Global Count
# 2. Desktop Section
# 3. Monitor Section
# 4. Individual Window Blocks
```

---

## 📄 Output File: `03_Window-List.data`

The generated file is a rich database of the current state.

| Variable | Example | Description |
| :--- | :--- | :--- |
| `WINDOW_COUNT` | `10` | Total active windows managed. |
| `WINDOW_N_DESKTOP` | `1` | The workspace index. |
| `WINDOW_N_MONITOR` | `2` | The physical monitor ID (1 or 2...). |
| `WINDOW_N_WID` | `0x03400199` | The Hex ID of the window. |
| `WINDOW_N_CLASS` | `Code` | Application class (for icons/grouping). |
| `WINDOW_N_MIN_WIDTH` | `600` | **New:** The application's forced minimum width. |
| `WINDOW_N_MIN_HEIGHT` | `405` | **New:** The application's forced minimum height. |
| `WINDOW_N_USER_TIME` | `1075254160` | Last time the user clicked/typed in this window. |
| `WINDOW_N_PROCESS_START_TIME` | `1763732226` | Epoch timestamp of when the app launched. |
| `WINDOW_N_TITLE` | `Firefox` | Cleaned, human-readable title. |