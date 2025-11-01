# 🔷 Float-to-Tile: Tiling Companion for Floating Window Managers

## 🚀 Project Mission
**Float-to-Tile** is a set of modular scripts written entirely in **Bash** (Shell Script) and using native **X11** tools (such as `xrandr`, `wmctrl`, and `xdotool`) to add robust *Tiling Window Manager* functionality to desktop environments that use the *Stacking* (Floating) paradigm by default.

The goal is to provide a lightweight, fast tiling experience with zero complex external dependencies, seamlessly integrating into environments like XFCE, GNOME, or MATE, without the need to migrate to a dedicated WM (such as i3 or Awesome).

## 🧩 Modular Architecture
The project is divided into modules orchestrated by the main script (`00_main.sh`):

1. **Data Collection Modules (`NN_*.sh`):** Scripts to capture the current state of the system (screen geometry, window IDs, positions, etc.).

2. **Action Modules (`A-NN_*.sh`):** Scripts to execute *tiling* actions (resize, move, focus, etc.).

All *tiling* is based on manipulating window properties (via `wmctrl` and `xdotool`) and precise knowledge of the *viewport* geometry (via `xrandr`).

## ⚙️ Dependencies
The project relies solely on command-line utilities widely available in Debian-based X11 environments:

* `xrandr` (For screen/monitor geometry)
* `wmctrl` (For listing and manipulating windows)
* `xdotool` (For obtaining the active window and sending focus commands)
* `awk`, `grep`, `cut` (For data processing)

---
For detailed information on each module, see the `Documentation/` folder.