# 📘 Module 01: Screen Geometry Capture (`01_Screen-Resolution.sh`)

## 🎯 Objective
To accurately determine the geometry of the X11 environment for tiling operations, ensuring robustness and failure tolerance:

- Dimensions of the global **Viewport (Total Desktop Area)**.  
- Geometry (size and position) of each **Active Monitor**.

---

## 🧠 Logic: Robustness and Valid State Persistence

This module achieves robustness by:

1. **Using native Bash Regular Expressions (`BASH_REMATCH`)** instead of AWK for parsing, avoiding cross-platform syntax issues.  
2. **Implementing a Fallback Mechanism:** It first tries `xrandr --listactivemonitors`. If that fails, it falls back to `xrandr --query`.  
3. **Valid State Persistence:** On successful completion, it backs up the current data to a `.last_valid_state` file, providing a safe fallback for subsequent modules.

---

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Setup, Path Configuration, and Cleanup

The script now uses relative paths based on the project's root directory:

```bash
ROOT_DIR="$(dirname "$(dirname "$0")")" # Points to the directory containing Scripts/, Logs/, etc.
LOG_FILE="$ROOT_DIR/Logs/01_Screen-Resolution.log"
DATA_FILE="$ROOT_DIR/Data/01_Screen-Resolution.data"
LAST_VALID_STATE_FILE="$ROOT_DIR/History/01_Screen-Resolution.last_valid_state"
TEMP_FILE="/tmp/xrandr_monitors_$$"
```

**Explanation:**

- `ROOT_DIR`: Crucial for resolving paths consistently from the `Scripts/` subfolder.  
- `LAST_VALID_STATE_FILE`: Now correctly placed in the `History/` directory.

---

### 2️⃣ Parsing Function and Data Acquisition (`_parse_file` & Acquisition)

The core parsing logic is encapsulated in the `_parse_file` function, which uses the modern `[[ $line =~ $geom_re ]]` syntax.

```bash
# Regex captures geometry (handling optional physical dimensions)
geom_re='([0-9]+)(/[^x+])?x([0-9]+)(/[^+ ])?+([0-9]+)+([0-9]+)'

_parse_file() {
    # ... (loop reads file line by line)
    if [[ $line =~ $geom_re ]]; then
        # ... (extracts values using BASH_REMATCH[N]) ...
        # ... (calculates max_width/max_height using arithmetic expansion $(()))
    fi
}
```

#### Acquisition & Fallback

```bash
if ! xrandr --listactivemonitors > "$TEMP_FILE" 2>/dev/null; then
    # if fail, try full query as fallback
    xrandr --query > "${TEMP_FILE}.full" 2>/dev/null || : > "${TEMP_FILE}.full"
    _parse_file "${TEMP_FILE}.full"
fi
```

**Explanation:**

- `BASH_REMATCH`: Array automatically populated by the `[[ =~ ]]` operator, holding captured groups (e.g., WIDTH is `${BASH_REMATCH[1]}`).  
- **Safety Advantage:** Avoids AWK syntax inconsistencies between different distros.  
- **Fallback Mechanism:** The script first attempts the compact `--listactivemonitors`. If it fails or yields incomplete data, it switches to the verbose `--query` output for higher resilience.

---

### 3️⃣ Data Assembly and Validation

The script assembles the output string (`AWK_OUTPUT`) manually and uses standard Bash tools (`sed`, `awk`) for final extraction and validation checks.

```bash
# Assemble AWK_OUTPUT-like block
AWK_OUTPUT="${MONITOR_DATA}---CALCULATED---"$'\n'"MONITOR_COUNT=${monitor_count}"$'\n'...

if [ -z "$VIEWPORT_WIDTH" ] || [ "$MONITOR_COUNT" -eq 0 ]; then
    # ... (Logs debug data and exits with failure)
    exit 1
fi
```

**Explanation:**

- **Assembly:** Data extracted in Bash is formatted to match the historical `AWK_OUTPUT` structure, ensuring compatibility with existing parsing logic in later phases.  
- **Validation:** If no geometry could be extracted after both primary and fallback attempts, the script exits with code `1`, signaling failure to the Orchestrator while providing detailed debug logs.

---

### 4️⃣ Output Generation and Valid State Backup

```bash
# Overwrite the current data file
{
    echo "VIEWPORT_WIDTH=$VIEWPORT_WIDTH"
    # ... (other data) ...
} > "$DATA_FILE"

# Valid State Persistence
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
```

**Explanation:**

- **Valid State Backup:** The `cp` operation ensures that only validated data (that passed all internal checks) is copied to `.last_valid_state`, maintaining safety and data consistency for downstream modules.