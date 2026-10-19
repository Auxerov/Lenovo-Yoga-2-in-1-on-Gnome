#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 01-pen-and-touch-fix.sh
# 
# Functionality:
# - HID-BPF kernel driver patch for Lenovo Digital Pen 2 & Wacom HID 5363 digitizer.
# - Hardware-level transformation of lower barrel button (Eraser mode) into BTN_STYLUS2.
# - Suppresses accidental tip clicks and pressure when holding barrel buttons during
#   navigation (Orbit / Pan) while grazing or touching the screen.
# - Configures GNOME Stylus button mappings (Lower -> Middle Click / Orbit, Upper -> Forward / Pan).
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BPF_OBJ="${SCRIPT_DIR}/resources/lenovo_pen_fix.bpf.o"

echo "=== [1/4] HID-BPF Driver & Udev Setup ==="
if [ ! -f "$BPF_OBJ" ]; then
    echo "ERROR: $BPF_OBJ not found!"
    exit 1
fi

sudo mkdir -p /etc/udev-hid-bpf /etc/udev/rules.d /etc/libwacom

# Copy BPF binary to system directory
sudo cp "$BPF_OBJ" /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o
sudo chmod 644 /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o

# Create Udev rule (loads BPF program when stylus device attaches or wakes up)
echo "Writing udev rule (/etc/udev/rules.d/99-hid-bpf-lenovo_pen_fix.rules)..."
sudo tee /etc/udev/rules.d/99-hid-bpf-lenovo_pen_fix.rules > /dev/null << 'EOF'
ACTION!="add|remove", GOTO="hid_bpf_end"
SUBSYSTEM!="hid", GOTO="hid_bpf_end"

# Lenovo Digital Pen 2 / Wacom HID 5363
ACTION=="add", ENV{MODALIAS}=="hid:b0018g0101v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf add --replace $sys$devpath /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o"
ACTION=="remove", ENV{MODALIAS}=="hid:b0018g0101v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf remove $sys$devpath"
ACTION=="add", ENV{MODALIAS}=="hid:b0018g*v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf add --replace $sys$devpath /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o"
ACTION=="remove", ENV{MODALIAS}=="hid:b0018g*v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf remove $sys$devpath"

LABEL="hid_bpf_end"
EOF

# Create systemd service for boot-time and resume persistence
echo "Creating systemd service (/etc/systemd/system/lenovo-pen-fix.service)..."
sudo tee /etc/systemd/system/lenovo-pen-fix.service > /dev/null << 'EOF'
[Unit]
Description=Lenovo Digital Pen 2 HID-BPF Driver Fix
After=systemd-udevd.service suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
Wants=systemd-udevd.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for dev in /sys/bus/hid/devices/*056A:5363*; do [ -d "$dev" ] && /usr/bin/udev-hid-bpf add --replace "$dev" /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

# Sleep/Resume hook to ensure BPF is re-attached immediately after waking from sleep
echo "Creating system-sleep hook (/etc/systemd/system-sleep/lenovo-pen-fix.sh)..."
sudo mkdir -p /etc/systemd/system-sleep
sudo tee /etc/systemd/system-sleep/lenovo-pen-fix.sh > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    post)
        /bin/systemctl restart lenovo-pen-fix.service
        ;;
esac
EOF
sudo chmod +x /etc/systemd/system-sleep/lenovo-pen-fix.sh

sudo systemctl daemon-reload
sudo systemctl enable --now lenovo-pen-fix.service

echo "=== [2/4] Libwacom Hardware Definitions ==="
# Ensure GNOME Settings identifies the stylus with two distinct barrel buttons
sudo tee /etc/libwacom/wacom-hid-5363-pen.tablet > /dev/null << 'EOF'
[Device]
Name=Wacom HID 5363 Pen
ModelName=WACF2200
Class=ISDV4
DeviceMatch=i2c|056a|5363
IntegratedIn=Display;System
Styli=0x56a:0x866c;

[Features]
Stylus=true
Reversible=false
Touch=true
NumRings=0
EOF

sudo tee /etc/libwacom/lenovo.stylus > /dev/null << 'EOF'
[0x56a:0x866c]
Name=Lenovo Digital Pen 2
Group=isdv4-aes
Buttons=2
EraserType=None
Axes=Tilt;Pressure
Type=Mobile
EOF

echo "=== [3/4] Injecting Driver into Running Hardware ==="
for dev in /sys/bus/hid/devices/*056A:5363*; do
    if [ -d "$dev" ]; then
        echo "Found device: $dev, attaching HID-BPF filter..."
        sudo /usr/bin/udev-hid-bpf add --replace "$dev" /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o || true
    fi
done

sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=hid || true

echo "=== [4/4] GNOME Stylus Button Mappings (Dconf) ==="
# Configure GNOME stylus button actions per user:
# - button-action (Upper button / Barrel 1) -> 'forward' (Blender Pan)
# - secondary-button-action (Lower button / Barrel 2) -> 'middle' (Blender Orbit)
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/button-action "'forward'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/secondary-button-action "'middle'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/eraser-button-action "'middle'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/eraser-button-mode "'button'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/pressure-curve "[0, 0, 100, 100]"

echo "-> Lenovo Digital Pen 2 & touch fixes successfully applied!"
