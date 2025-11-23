# 📘 Module 01: Screen Geometry Capture (`01_Screen-Resolution.sh`)

## 🎯 Objective
To accurately interrogate the X11 display server and determine the physical environment layout. This module serves as the foundation for the tiling logic by establishing the boundaries where windows can be placed.

**Captured Data:**
1. **Global Viewport:** The total combined width and height of all active screens (the complete "desktop area").
2. **Individual Monitors:** Name, resolution (W x H), and position (X, Y) for each active monitor.

---

## 🧠 Logic: Robustness & Persistence

To ensure the script runs reliably across different distributions and hardware configurations, it relies on three pillars of robustness:

1. **Absolute Path Resolution:** It does not depend on the working directory. It resolves its location dynamically using `${BASH_SOURCE[0]}`.
2. **Native Parsing (Bash Regex):** Replaces external tools like `awk` (which can vary by version) with native Bash Regular Expressions, preventing syntax compatibility issues.
3. **Fallback Mechanism:** It attempts the modern method (`--listactivemonitors`) first. If that fails or returns zero monitors, it automatically falls back to the legacy method (`--query`).

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Path Configuration & Cleanup (`Path & Trap`)

The script initializes by locating itself. This ensures logs and data files are written to the correct relative paths (`../Logs`, `../Data`), regardless of where the script is called from.

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
# ... Log and Data file definitions ...

# Ensures the temp file is deleted upon exit (success or error)
trap 'rm -f "$TEMP_FILE"' EXIT
```

* **`${BASH_SOURCE[0]}`:** Safer than `$0`. It ensures the path is detected correctly even if the script is "sourced" or run via a symlink.
* **`trap ... EXIT`:** A safety net. As soon as the script finishes (or if it crashes), it executes `rm`, ensuring no garbage is left in `/tmp`.

---

### 2️⃣ The Parsing Logic (`_parse_file` & Regex)

This is the core intelligence of the script. Instead of relying on fixed text columns (which may change between `xrandr` versions), we use a **Regular Expression** to hunt for the geometry pattern.

**The Regex:**
`geom_re='([0-9]+)(/[^x+]*)?x([0-9]+)(/[^+ ]*)?\+([0-9]+)\+([0-9]+)'`

**How it processes a line like:** `0: +*eDP-1 1920/344x1080/194+360+1620`

| Regex Group | Captures | Example Value | Meaning |
| :--- | :--- | :--- | :--- |
| `([0-9]+)` | **Width** | `1920` | Horizontal pixels |
| `(/[^x+]*)?` | *(Ignored)* | `/344` | Physical mm (skipped) |
| `x` | Separator | `x` | Resolution "by" |
| `([0-9]+)` | **Height** | `1080` | Vertical pixels |
| `(/[^x+]*)?` | *(Ignored)* | `/194` | Physical mm (skipped) |
| `\+` | Separator | `+` | Coord start |
| `([0-9]+)` | **Pos X** | `360` | Distance from left |
| `\+` | Separator | `+` | Coord separator |
| `([0-9]+)` | **Pos Y** | `1620` | Distance from top |

Bash automatically stores these in the `${BASH_REMATCH}` array:
* `${BASH_REMATCH[1]}` = Width
* `${BASH_REMATCH[3]}` = Height
* `${BASH_REMATCH[5]}` = Position X
* `${BASH_REMATCH[6]}` = Position Y

---

### 3️⃣ Acquisition & Fallback Strategy

The script is persistent. It tries the cleanest method first, but is prepared to handle failure.

```bash
# 1. Try to get a clean list of monitors
if ! xrandr --listactivemonitors > "$TEMP_FILE" 2>/dev/null; then
    : > "$TEMP_FILE" # Create empty if command fails
fi

_parse_file "$TEMP_FILE"

# 2. FAILURE CHECK: If no monitors were detected (count is 0)
if [ "$monitor_count" -eq 0 ]; then
    log "FALLBACK: TRYING XRANDR --QUERY"
    # 3. Try the verbose/legacy method
    xrandr --query > "${TEMP_FILE}.full" 2>/dev/null
    _parse_file "${TEMP_FILE}.full"
fi
```

**The Flow:**
1. Runs `listactivemonitors`.
2. Parses the file.
3. If `$monitor_count` remains **0**, the script assumes something went wrong (command ran but returned no valid geometry).
4. It then runs `xrandr --query` (much more verbose output) and applies the same Regex logic to it.

---

### 4️⃣ Validation & Output

Before saving, the script validates if the data "makes sense". If the viewport width or height is empty, it aborts to prevent data corruption.

If successful, it generates a `.data` file with this standardized structure:

```ini
VIEWPORT_WIDTH=2880       # Combined total width
VIEWPORT_HEIGHT=2700      # Combined total height
MONITOR_COUNT=2           # Number of monitors found
# Monitor 1 Details
MONITOR_1_NAME=eDP-1-1
MONITOR_1_WIDTH=1920
MONITOR_1_HEIGHT=1080
MONITOR_1_POS_X=360
MONITOR_1_POS_Y=1620
# Monitor 2 Details, etc...
```

### 5️⃣ State Persistence (`Last Valid States`)

```bash
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
```

Upon successful completion, the script backs up the `.data` file to the `Last-Valid-States/` directory.
* **Why?** If you run the script tomorrow and `xrandr` fails completely (e.g., driver error), downstream modules can be configured to read from `last_valid_state` instead of crashing, using the last known working configuration.