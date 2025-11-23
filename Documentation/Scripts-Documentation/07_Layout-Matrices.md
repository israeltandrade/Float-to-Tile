# 🧱 Module 07: Layout Matrices (`07_Layout-Matrices.sh`)

## 🎯 Objective
To transform the linear window lists (from **M06**) into **abstract geometrical blueprints** (Matrices).

While Module 06 decides *which* windows are in a group, Module 07 decides *how* they relate to each other spatially. It generates two distinct layout models for every group:
1. **2D Matrix (Master/Stack):** A simple vertical split (Left=Master, Right=Stack).
2. **3D Matrix (Fibonacci):** A recursive spiral split, defining deep nesting (Left, Top-Right, Bottom-Right, etc.).

**New in v2.6:** This module now generates sophisticated **ASCII Visual Previews** directly in the data file, allowing developers to visualize the layout logic without applying it.

---

## 🧠 Logic: Matrix Models

 The script iterates through every `D{N}_M{N}_CYCLE_LIST` and maps window IDs (WIDs) to specific matrix coordinates.

### 1. The 2D Model (Standard Tiling)
Used for standard "Master/Stack" layouts.
* **Index `0`:** The Master Window (Main focus).
* **Index `1.x`:** The Stack (Secondary windows).
* **Structure:** `[ 0 ] | [ 1.0 ] [ 1.1 ] [ 1.2 ]...`

### 2. The 3D Model (Recursive/Fibonacci)
Used for "Spiral" or "Dwindle" layouts. It defines a recursive split tree.
* **0:** Primary Half.
* **1.0:** Top of the remaining half.
* **1.1.0:** Left of the remaining quarter...
* **Logic:** Every step down the hierarchy splits the remaining space in half (alternating Horizontal/Vertical).

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Title Mapping & Normalization
Before processing layouts, the script builds a lookup map (`WID_TO_TITLE`) to fetch human-readable names for the ASCII previews.
* It decodes Unicode characters (e.g., `\u0026` -> `&`).
* It cleans quotes and control characters.

### 2️⃣ Visual Preview Generation (ASCII Art)
This version places heavy emphasis on "Debuggability". It calculates string lengths to generate aligned ASCII tables.

* **Truncation:** For the ASCII table, names are truncated to `MAX_NAME_WIDTH` (20 chars) to keep the table readable.
* **Matricial Preview:** Displays the **Full Untruncated Name** in the commented variable list for detailed inspection.
* **Equalization:** It calculates the maximum cell width required across both 2D and 3D views so the ASCII grids align perfectly when viewed in a text editor.

```bash
# Example logic for cell building
build_cell() {
    local centered="$(center "$(trunc "$name" "$inner_w")" "$inner_w")"
    printf '%-*s' "$cell_w" "$(printf -- '- %s - ' "$centered")"
}
```

---

## 📄 Output File: `07_Layout-Matrices.data`

This file acts as both a data source for the Tiling Engine and a debug report for the user.

### 1. ASCII Visual Previews (Comments)
The file includes rendered tables showing exactly how the windows are distributed.

```text
# === 2D Matrix (Master/Stack Vertical) ASCII PREVIEW ===
# --- Master ---       | --- Stack ----       |
# -     Chrome     -   | -    Terminal    -   |
# -     Chrome     -   | -    Telegram    -   |

# === 3D Matrix (Fibonacci) ASCII PREVIEW ===
# -     Chrome     -   | -    Terminal    -   | 
# -     Chrome     -   | -    Telegram    -   | 
# -     Chrome     -   | -      Code      -   | 
```

### 2. Variable Definitions (The Blueprint)
These are the variables read by the Tiling Script.

| Variable Key | Value (WID) | Meaning |
| :--- | :--- | :--- |
| `..._MATRIX_2D_0` | `0x0340001` | The Master Window. |
| `..._MATRIX_2D_1.0` | `0x0340002` | The first window in the stack column. |
| `..._MATRIX_3D_1.1` | `0x0340003` | A window deep in the recursive spiral. |

### Example Data Block:

```ini
# ================= DESKTOP 1 (VISUAL INDEX: 1 | NAME: Web) =================
# ------------- MONITOR 2 (HDMI-0) -------------

# --- 2D Matrix (Master/Stack Vertical) ---
# MATRICIAL PREVIEW (2D):
# D1_M2_MATRIX_2D_0=Google Chrome - Wikipedia
# D1_M2_MATRIX_2D_1_0=Alacritty

D1_M2_MATRIX_2D_0=0x03400014
D1_M2_MATRIX_2D_1_0=0x03200037
```