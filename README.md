# 🔷 Float-to-Tile: Tiling Companion for Floating Window Managers

## 🚀 Project Mission
**Float-to-Tile** is a set of modular scripts written entirely in **Bash (Shell Script)** and using native X11 tools (such as `xrandr`, `wmctrl`, and `xdotool`) to add robust **Tiling Window Manager** functionality to desktop environments that use the **Stacking (Floating)** paradigm by default.

The goal is to provide a lightweight and fast tiling experience with **zero complex external dependencies**, seamlessly integrating into environments such as **XFCE, GNOME, or MATE**, without the need to migrate to a dedicated WM (such as i3 or Awesome).

---

## 🧩 Modular Architecture
The project is divided into modules orchestrated by the main script `run.sh`:

- **Data Collection Modules (`NN_*.sh`)**

Scripts located in the `Scripts/` folder that capture the current state of the system (screen geometry, window IDs, positions, etc.).

- **Action Modules (`A-NN_*.sh`)**

Scripts to execute tiling actions (resize, move, focus, etc.).

> 💡 All tiling is based on manipulating window properties (via `wmctrl` and `xdotool`) and precise knowledge of the viewport geometry (via `xrandr`).

--

## ⚙️ Dependencies
The project depends only on command-line utilities widely available in Debian-based **X11** environments:

| Dependency | Main Function |

| :----------- | :---------------- |

| `xrandr` | Screen and monitor geometry |

| `wmctrl` | Window listing and manipulation |

| `xdotool` | Active window identification and focus command sending |

| `awk`, `grep`, `cut` | Data processing and filtering |

---

📁 **For detailed information about each module**, please refer to the `Documentation/` folder.