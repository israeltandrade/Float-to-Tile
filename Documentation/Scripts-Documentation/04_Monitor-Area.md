# 📐 Module 04: Monitor Area Calculation (`04_Monitor-Area.sh`)

## 🎯 Objective
To calculate the **Effective Working Area** for each monitor.
While Module 01 captures the *physical* resolution, this module calculates the *logical* area where windows are allowed to exist, by subtracting user-defined padding (gaps) defined in the global configuration.

**Why is this needed?**
It prevents tiled windows from touching the physical edges of the screen or overlapping with reserved spaces (like system bars not managed by EWMH), creating an aesthetic "floating" gap effect.

---

## 🧠 Logic: The Subtraction Method

The script acts as a geometry processor. It takes the **Raw Monitor Dimensions** and applies a **Padding Transformation**.

### The Formula
For every monitor $N$, the script applies these coordinate shifts:

| Dimension | Calculation Logic | Visual Effect |
| :--- | :--- | :--- |
| **New X (Start)** | $RawX + PaddingLeft$ | Pushes the window area right, away from the left edge. |
| **New Y (Start)** | $RawY + PaddingTop$ | Pushes the window area down, away from the top bar. |
| **New Width** | $RawWidth - (PaddingLeft + PaddingRight)$ | Shrinks total width to fit within margins. |
| **New Height** | $RawHeight - (PaddingTop + PaddingBottom)$ | Shrinks total height to fit within margins. |

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Dependency Loading & Defaults
The script is robust against missing configuration values. It attempts to load `global_config.conf`. If a specific padding variable is missing, it defaults to `0` using Bash parameter expansion (`:-0`).

```bash
# Load Config
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

# Set defaults if config is silent
PT="${PADDING_TOP_PX:-0}"
PB="${PADDING_BOTTOM_PX:-0}"
PL="${PADDING_LEFT_PX:-0}"
PR="${PADDING_RIGHT_PX:-0}"
```

---

### 2️⃣ The Calculation Loop
The script iterates through the dynamic number of monitors found in Module 01 (`MONITOR_COUNT`). It uses **Indirect Expansion** (`${!VAR}`) to read dynamic variable names like `MONITOR_1_WIDTH`, `MONITOR_2_WIDTH`, etc.

```bash
for ((i = 1; i <= MONITOR_COUNT; i++)); do
    # Indirect expansion to get raw data for Monitor $i
    X_VAR="MONITOR_${i}_POS_X"; X=${!X_VAR}
    W_VAR="MONITOR_${i}_WIDTH"; W=${!W_VAR}
    # ... (Y and H loaded similarly) ...

    # Apply Geometry Math
    NEW_X=$((X + PL))
    NEW_Y=$((Y + PT))
    NEW_W=$((W - PL - PR))
    NEW_H=$((H - PT - PB))

    # Write to temp buffer
    printf "USABLE_AREA_%s_X=%s\n" "$i" "$NEW_X" >> "$TEMP_FINAL_DATA"
    # ...
done
```

---

### 3️⃣ Output Generation & Persistence
Like previous modules, it saves the active data and creates a backup state. This allows downstream tiling algorithms to run even if this script is momentarily skipped, by reading the `last_valid_state`.

```bash
cat "$TEMP_FINAL_DATA" > "$DATA_FILE"
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
```

---

## 📄 Output File: `04_Monitor-Area.data`

This file defines the "Canvas" for the tiling engine.

| Variable | Example | Description |
| :--- | :--- | :--- |
| `USABLE_AREA_1_X` | `369` | The absolute X pixel where windows usually start on Monitor 1. |
| `USABLE_AREA_1_Y` | `1674` | The absolute Y pixel where windows usually start on Monitor 1. |
| `USABLE_AREA_1_WIDTH` | `1902` | The actual width available for windows (Physical Width - Gaps). |
| `USABLE_AREA_1_HEIGHT` | `972` | The actual height available for windows (Physical Height - Gaps). |