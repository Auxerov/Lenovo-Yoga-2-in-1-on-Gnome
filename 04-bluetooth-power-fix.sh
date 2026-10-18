#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 04-bluetooth-power-fix.sh
# 
# Functionality:
# - Realtek Bluetooth (0bda:5852) Power Management & Disconnection Fix:
#   * Linux kernel USB autosuspend causes latency, audio stutter, or dropouts
#     on wireless headphones, mice, and stylus connections.
#   * This udev rule forces the Realtek Bluetooth USB device power control to 'on'
#     permanently, preventing unwanted sleep cycles.
# ==============================================================================

set -e

echo "=== [1/2] Installing Bluetooth Udev Power Rule ==="
sudo tee /etc/udev/rules.d/50-bluetooth-power.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5852", ATTR{power/control}="on"
EOF

echo "=== [2/2] Applying to Live System ==="
sudo udevadm control --reload
sudo udevadm trigger --subsystem-match=usb || true

# Apply directly via sysfs to currently active device
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        v=$(cat "$dev/idVendor" 2>/dev/null || true)
        p=$(cat "$dev/idProduct" 2>/dev/null || true)
        if [ "$v" = "0bda" ] && [ "$p" = "5852" ]; then
            if [ -f "$dev/power/control" ]; then
                echo "on" | sudo tee "$dev/power/control" > /dev/null
                echo "Set Bluetooth power control to 'on': $dev"
            fi
        fi
    fi
done

echo "-> Bluetooth power management rule successfully configured!"
