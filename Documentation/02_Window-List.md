# 📘 Module 02: Window List Capture (02_Window-List.sh)

## 🎯 Objective

To generate a comprehensive list of all managed windows (i.e., applications, excluding desktop utilities and panels) and extract the necessary geometric and classification data for the tiling algorithm.

## 🧠 Logic: Data Selection and Filtering

This module relies on the wmctrl -lxG output, which provides window IDs, geometry, and class names in a single, well-defined line format.

### Key Logic Points:

Input Data: Uses the full output of wmctrl -lxG to obtain Window ID, Desktop/Workspace, X/Y position, Width/Height, and the ClassName.ResourceName (WM_CLASS).

Exclusion: Windows are filtered out based on their Desktop/Workspace (-1 usually means sticky or desktop) and their Class Name (excluding known utilities like xfce4-panel and xfdesktop) using AWK pattern matching.

Classification: The ClassName.ResourceName field is explicitly split into separate CLASS and RESOURCE fields to allow for granular identification rules in the Tiling Module (M03).

Valid State: Having zero managed windows is considered a valid state (Module 02 will exit 0 even if WINDOW_COUNT=0). It updates the .last_valid_state file in all successful executions.

## 💾 Code Breakdown (by Logical Blocks)

### 1️⃣ Setup and Data Acquisition

```bash

... (Configuration, log function, trap setup) ...

if ! wmctrl -lxG > "$TEMP_FILE"; then
log "FAILURE: Command 'wmctrl -lxG' failed."
exit 1
fi
```
#### Explanation:

wmctrl -lxG: The critical command. It outputs the full window list, including geometry (G) and class/resource names (x), essential for filtering.

Guard Clause: If wmctrl fails, the script exits 1. This is a hard dependency.

### 2️⃣ AWK Filtering and Parsing

This block defines the filtering criteria and extracts the 9 essential window properties.

```bash
AWK_OUTPUT=$(awk '
# ... (Initialization) ...

# Filter: Exclude known utilities and desktop windows
! /xfce4-panel|xfdesktop/ && $2 != "-1" { 
    # ... (Processing logic) ...
    
    # Rebuild Title: Starts from column 9 to the end of the line
    window_title = "";
    for (i = 9; i <= NF; i++) {
        # ... (Title reconstruction) ...
    }

    # Output the required KEY=VALUE pairs
    # ... (prints) ...
}

END { 
    print "---CALCULATED---";
    print "WINDOW_COUNT=" window_count;
}


' "$TEMP_FILE")
```
#### Explanation:

Filtering (! /xfce4-panel|.../): Excludes common elements of the XFCE desktop environment by Class/Resource name and the desktop ID of -1.

Title Rebuilding: Because the window title starts at column 9 and may contain spaces, a simple loop is required to reconstruct the full title string from column 9 onwards.

### 3️⃣ Validation and Zero-Window Handling

The validation specifically handles the case where no windows are found.

```bash
if [ -z "$WINDOW_COUNT" ] || [ "$WINDOW_COUNT" -eq 0 ]; then
log "SUCCESS (Empty): No standard windows found to manage. WINDOW_COUNT=0."

# Creates minimal data files and exits 0 (SUCCESS)
printf "WINDOW_COUNT=0\n" > "$DATA_FILE"
cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
exit 0


fi
```
#### Explanation:

Valid State: The absence of managed windows is not a system error. The script registers WINDOW_COUNT=0 in the output files and exits successfully (exit 0), ensuring pipeline continuity.

### 4️⃣ Output and Persistence

If windows are found, the data is written to the primary and valid state files.

```bash

Separate Window Data from Calculated Data

WINDOW_DATA=$(echo "$AWK_OUTPUT" | sed -n '1,/---CALCULATED---/ { /---CALCULATED---/d; p }')

Overwrite the current data file

{
echo "WINDOW_COUNT=$WINDOW_COUNT"
echo "$WINDOW_DATA"
} > "$DATA_FILE"

cp "$DATA_FILE" "$LAST_VALID_STATE_FILE"
exit 0
```
#### Explanation:

Persistence: The data is backed up to the .last_valid_state file, ensuring later modules have a reliable list, even if a future run of wmctrl fails.