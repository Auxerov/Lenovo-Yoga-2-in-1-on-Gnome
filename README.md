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
| **`01-pen-and-touch-fix.sh`** | **Stylus & Touchscreen Patch:** Injects a custom HID-BPF kernel filter for the Lenovo Digital Pen 2 / Wacom HID 5363 digitizer. Converts the lower barrel button's eraser report into `BTN_STYLUS2`; suppresses accidental tip clicks when holding barrel buttons on screen; sets up GNOME stylus mappings (Lower: Middle Click/Orbit, Upper: Forward/Pan). |
| **`02-sleep-and-suspend-to-disk.sh`** | **Mac-style Smart Sleep & SSD Hibernation:** Keeps the system in fast RAM sleep for the first 30 minutes (instant resume). After 30 minutes, it writes the entire session to SSD swap (`suspend-then-hibernate`) for zero battery drain. Also disables PCIe/ACPI spurious wakeups (`GPP6`/`GPP7`) to prevent overheating in a backpack. |
| **`03-battery-conservation.sh`** | **Battery Health Conservation:** Limits battery charge to ~80% when plugged in to prevent lithium-ion degradation. Also installs the terminal utility `bat-limit` (`bat-limit on`, `bat-limit off`, `bat-limit status`). |
| **`04-bluetooth-power-fix.sh`** | **Bluetooth Power Stability:** Sets the Realtek USB Bluetooth controller (`0bda:5852`) power control permanently to `on`, preventing autosuspend audio lag and peripheral dropouts. |
| **`05-disable-remote-desktop-popups.sh`** | **Remote Desktop Notification Suppressor:** Disables the RemoteDesktop XDG portal interface, clears stuck portal sessions, and permanently eliminates the '+ 2 Remote Desktop' nag dialogs and top bar indicators without affecting screen recording or Discord/OBS streaming. |
| **`06-affinity-linux-optimization.sh`** | **Affinity Suite (Wine) Tuning:** Resolves the fatal new document preset crash by disabling the unimplemented `ninput.dll` stub, forces Wintab mode, configures DXVK low-latency buffer flags (`maxFrameLatency = 1`), and caps memory limit to 8 GB. |
| **`07-blender-yoga-tuning.sh`** | **Blender & Radeon 780M Tuning:** Unsets legacy ROCm/HIP environment variables to enable native gfx1103 GPU rendering and documents the 3D viewport stylus navigation bindings. |
| **`08-librewolf-dpi-discord.sh`** | **Discord & Censorship DPI Bypass:** Sets clean Cloudflare/Google DNS, enables Cloudflare DNS-over-HTTPS (DoH), and runs a lightweight local SpoofDPI proxy service (`127.0.0.1:8080`) with selective PAC routing. Discord connects seamlessly with packet fragmentation bypassing ISP inspection, while all other sites connect 100% directly with zero speed loss and zero VPN latency. |
| **`resources/`** | Contains the HID-BPF C source code (`lenovo_pen_fix.bpf.c`) and precompiled object file (`lenovo_pen_fix.bpf.o`). |

---

## 🛠️ Standalone Commands
- **Battery Conservation Control:**
  - `bat-limit on`     : Caps charging at ~80% (ideal for daily AC power use).
  - `bat-limit off`    : Charges up to 100% (ideal before traveling).
  - `bat-limit status` : Prints current battery level and conservation status.
- **SpoofDPI Service Control:**
  - `systemctl --user status spoofdpi.service`  : Checks background DPI bypass proxy status.
  - `systemctl --user restart spoofdpi.service` : Restarts DPI proxy.
