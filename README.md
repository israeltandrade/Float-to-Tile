## 🔷 Float-to-Tile: The Non-Invasive Tiling Companion

Bring the efficiency of **Tiling Window Managers** to your favorite Desktop Environment  
(**XFCE, GNOME, MATE**) using **pure Bash**.

---

## 🚀 Project Mission

**Float-to-Tile** acts as a lightweight **compatibility layer** that adds tiling capabilities  
to traditional *Stacking (Floating) Window Managers*.

Unlike replacing your entire workflow with a full Tiling WM (i3, Awesome, bspwm), this project is:

- **Non-invasive** — does not replace your Desktop Environment  
- **Event-driven** — only runs when manually triggered  
- **X11-native** — uses standard, well-documented protocols  
- **Fully Bash-based** — transparent, hackable, and dependency-light  

Its goal is to provide **tiling power** without disrupting your desktop ecosystem.

---

## 🏗️ Architecture & Directory Structure

The system follows a strict **Separation of Concerns**:

- **Scripts (01–07)** → *Data collection and analysis*  
- **Actions (ACXX)** → *Window movement and layout application*  
- **Documentation/** → *Mirrors the structure and explains the logic*  
- **Last-Valid-States/** → *Safety and rollback*  

---

## 📂 Directory Map

### Project Structure Overview

| Directory | Purpose |
|----------|---------|
| **Actions/** | Scripts that *move/resize windows* (e.g., `AC01_Tile-Vertical.sh`). Maintains its own logs and last-valid-state snapshots. |
| **Data/** | Raw data outputs from analysis scripts (resolution, monitor areas, window lists, cycle maps, etc.). |
| **Documentation/** | Central knowledge base explaining the math and logic for each script. Mirrors the directory structure. |
| **Last-Valid-States/** | Stores the last known *good state* for safe recovery or toggle-back operations. |
| **Logs/** | Execution logs from the data collection phase, including geometry/debug diagnostics. |
| **Scripts/** | The “Sensors”: numbered 01–07, responsible for querying the X server and modeling the screen mathematically. |

---

## 📚 How to Navigate the Documentation

Each code file has a **1:1 documentation match**, ensuring readability and transparency.

When you want to understand a script:

> **Look for the documentation file with the exact same name.**

### Mapping Example

| Code Location | Documentation Location | Purpose |
|---------------|-------------------------|---------|
| `Scripts/01_Screen-Resolution.sh` | `Documentation/Scripts-Documentation/01_Screen-Resolution.md` | Explains how screen geometry is computed. |
| `Actions/AC01_Tile-Vertical.sh` | `Documentation/Actions-Documentation/AC01_Tile-Vertical.md` | Explains the logic behind the vertical tiling action. |

---

## ⚙️ Dependencies

Float-to-Tile relies exclusively on **X11 standard utilities**, available in virtually all Linux distros.

| Tool | Usage |
|------|-------|
| **xrandr** | Maps the screen canvas: monitor IDs, offsets, DPI, resolutions. |
| **wmctrl** | Lists windows, detects state (maximized, hidden, type), and moves/resizes windows. |
| **xdotool** | Handles focus, retrieving active WID, and sending window commands. |
| **coreutils** | `awk`, `grep`, `sed` used for high-performance parsing of X11 outputs. |

---

## ✔️ Summary

Float-to-Tile provides:

- Tiling WM power  
- Without replacing your DE  
- Using only Bash + X11  
- With clean architecture  
- And 100% transparent logic  

A **non-invasive**, **hackable**, and **modular** approach to intelligent tiling overlays.