# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
**Author:** Auxerov  
**Target Hardware:** Lenovo Yoga 7 2-in-1 14AHP9 (AMD Ryzen 7 8840HS, Radeon 780M, Wacom HID 5363 Digitizer)  
**Operating System:** Fedora Linux (GNOME on Wayland)

---

## 📌 Overview
This repository contains a modular collection of kernel driver patches, system services, and hardware optimizations tailored specifically for the Lenovo Yoga 7 2-in-1 under Linux.

It provides a single-command master setup script as well as standalone scripts to re-apply any specific driver, performance, or network bypass fix whenever needed.

---

## 🚀 Quick Start (Apply Everything)
To apply or restore all settings in one shot, navigate to this directory and run:

```bash
cd ~/Documents/"Lenovo 2 in 1 Settings"
./apply-all.sh
```

---

## 📂 File Structure & Functionality

| File Name | Description & Core Purpose |
| :--- | :--- |
| **`apply-all.sh`** | **Master Runner:** Executes all configuration scripts sequentially with a single upfront `sudo` prompt. |
| **`01-pen-and-touch-fix.sh`** | **Stylus & Touchscreen Patch:** Injects a custom HID-BPF kernel filter for the Lenovo Digital Pen 2 / Wacom HID 5363 digitizer. Converts the lower barrel button's eraser report into `BTN_STYLUS2`; suppresses accidental tip clicks when holding barrel buttons on screen; sets up GNOME stylus mappings (Lower: Middle Click/Orbit, Upper: Forward/Pan); and includes sleep/resume persistence across suspends. |
| **`02-sleep-and-suspend-to-disk.sh`** | **Mac-style Smart Sleep & SSD Hibernation:** Keeps the system in fast RAM sleep for the first 30 minutes (instant resume). After 30 minutes, it writes the entire session to SSD swap (`suspend-then-hibernate`) for zero battery drain. Also disables PCIe/ACPI spurious wakeups (`GPP6`/`GPP7`) to prevent overheating in a backpack. |
| **`03-battery-conservation.sh`** | **Battery Health Conservation:** Limits battery charge to ~80% when plugged in to prevent lithium-ion degradation. Also installs the terminal utility `bat-limit` (`bat-limit on`, `bat-limit off`, `bat-limit status`). |
| **`04-bluetooth-power-fix.sh`** | **Realtek RTL8852CE Wi-Fi/Bluetooth Coexistence & Audio Stutter Fix:** Resolves the known Realtek firmware coexistence regression (`rtw8852c_fw-2.bin`) that chokes Bluetooth audio during network activity, disables USB autosuspend (`btusb enable_autosuspend=n`), turns off Wi-Fi radio power cycling (`rtw89_core disable_ps_mode=y`) and PCIe ASPM L1/L1SS transitions, disables NetworkManager Wi-Fi powersave, tunes BlueZ, and elevates WirePlumber audio priority to eliminate packet drops and audio cutouts. |
| **`05-disable-remote-desktop-popups.sh`** | **Remote Desktop Notification Suppressor:** Disables the RemoteDesktop XDG portal interface, clears stuck portal sessions, and permanently eliminates the '+ 2 Remote Desktop' nag dialogs and top bar indicators without affecting screen recording or Discord/OBS streaming. |
| **`06-affinity-linux-optimization.sh`** | **Affinity Suite (Wine) Tuning:** Resolves the fatal new document preset crash by disabling the unimplemented `ninput.dll` stub, forces Wintab mode, configures DXVK low-latency buffer flags (`maxFrameLatency = 1`), and caps memory limit to 8 GB. |
| **`07-blender-yoga-tuning.sh`** | **Blender & Radeon 780M Tuning:** Unsets legacy ROCm/HIP environment variables to enable native gfx1103 GPU rendering, and automatically injects stylus 3D viewport navigation keymaps (Lower button = Orbit / Middle Click, Upper button = Pan / Shift + Middle Click via `BUTTON5MOUSE`). |
| **`Blender on 2 in 1.sh`** | **Comprehensive Blender Suite Setup:** All-in-one setup for Blender on Lenovo Yoga 7 2-in-1. Configures Radeon 780M HIP compute, Wayland HiDPI scaling, evdev input group elevation, GNOME Stylus dconf mappings, Blender viewport keymaps, Vimender addon deployment, and `.desktop` launcher. |
| **`08-librewolf-dpi-discord.sh`** | **Discord & Censorship DPI Bypass:** Sets clean Cloudflare/Google DNS, enables Cloudflare DNS-over-HTTPS (DoH), and runs a lightweight local SpoofDPI proxy service (`127.0.0.1:8080`) with selective PAC routing. Discord connects seamlessly with packet fragmentation bypassing ISP inspection, while all other sites connect 100% directly with zero speed loss and zero VPN latency. |
| **`09-foliate-vertical-matte-black.sh`** | **Foliate Continuous Vertical Reading, Matte Black, Shelf System & Native PDF Support:** Enables continuous vertical scrolling (webtoon / document mode), installs a soothing matte black background theme (`#121212` / `#e0e0e0` text) to eliminate glare, patches the Foliate paginator so scrolling or swiping past chapter boundaries seamlessly advances to adjacent sections, adds a full shelf/collection management system in the library sidebar, introduces right-click "Mark as Read" (100% progress) / "Add to Shelf…" actions, and enables native PDF document reading with GTK file chooser filters, cover thumbnail generation, and desktop MIME association. |
| **`10-appflowy-oled-black-theme.sh`** | **AppFlowy True Pure Black OLED Themes:** Installs and packages true `#000000` pitch black OLED themes for AppFlowy (`OLED Black` with Catppuccin soft blue accent, and `OLED Monochrome` with crisp minimalist white accent). Deploys valid `.flowy_plugin` packages with all 55 FlowyColorScheme color tokens to AppFlowy's document discovery and sandbox folders, and configures the default theme in the application database. |
| **`11-yogatouch-expresskeys.sh`** | **YogaTouch Floating ExpressKeys & 4-Finger Gesture Suite:** PureRef-style always-on-top floating touch express dock tailored for 2-in-1 touchscreen artists and creators. Activated smoothly by 4-finger pinch-inward ("ortaya çekme") gesture on touchscreen or touchpad (or `Super+O`). Floats in the top-right corner over Blender, Affinity, Krita, and notes without stealing focus, permitting simultaneous stylus drawing and left-finger modifier taps (Shift, Ctrl, Alt, Space, MMB Orbit, Undo, Brush, etc.). Includes full in-app customization GUI, mouse wheel opacity control, and profile management. |
| **`resources/`** | Contains the HID-BPF C source code (`lenovo_pen_fix.bpf.c`), precompiled object (`lenovo_pen_fix.bpf.o`), Foliate enhanced assets (`app.js`, `pdf.js`, `paginator.js`, `library.js`, `reader.js`, `matte-black.json`, etc.), AppFlowy OLED theme plugin bundles, and complete YogaTouch ExpressKeys source code. |

---

## 🛠️ Standalone Commands
- **YogaTouch ExpressKeys Control:**
  - `yogatouch --toggle` : Toggles the floating touch dock (or use 4-finger pinch inward or `Super+O`).
  - `yogatouch --show`   : Displays and raises the touch dock.
  - `yogatouch --hide`   : Hides the touch dock.
  - `yogatouch --status` : Checks if the background daemon is running.
  - `systemctl --user restart yogatouch.service` : Restarts the background gesture monitor service.
- **Battery Conservation Control:**
  - `bat-limit on`     : Caps charging at ~80% (ideal for daily AC power use).
  - `bat-limit off`    : Charges up to 100% (ideal before traveling).
  - `bat-limit status` : Prints current battery level and conservation status.
- **SpoofDPI Service Control:**
  - `systemctl --user status spoofdpi.service`  : Checks background DPI bypass proxy status.
  - `systemctl --user restart spoofdpi.service` : Restarts DPI proxy.
