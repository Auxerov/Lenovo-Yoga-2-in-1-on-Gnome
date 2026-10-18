#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 02-sleep-and-suspend-to-disk.sh
# 
# Functionality:
# - Mac-style Smart Sleep Mode (suspend-then-hibernate):
#   * First 30 minutes: The laptop stays in fast RAM sleep (instant resume).
#   * After 30 minutes: Memory state is written to SSD swap space and enters deep
#     hibernation. This guarantees zero battery drain while sleeping in a backpack.
# - Backpack Wakeup Prevention (PCIe/ACPI Wakeup Masking):
#   * Disables GPP6 and GPP7 ACPI wakeups (Realtek Wi-Fi and SD card reader) so
#     the laptop does not unexpectedly wake up, drain battery, or overheat.
# ==============================================================================

set -e

echo "=== [1/3] Systemd Sleep Configuration (Mac-Sleep) ==="
sudo mkdir -p /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d

echo "Writing /etc/systemd/sleep.conf.d/mac-sleep.conf..."
sudo tee /etc/systemd/sleep.conf.d/mac-sleep.conf > /dev/null << 'EOF'
[Sleep]
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
HibernateDelaySec=30min
EOF

echo "=== [2/3] Systemd Logind Configuration (Lid & Power Key) ==="
echo "Writing /etc/systemd/logind.conf.d/mac-sleep.conf..."
sudo tee /etc/systemd/logind.conf.d/mac-sleep.conf > /dev/null << 'EOF'
[Login]
# On battery: lid close triggers suspend-then-hibernate (after 30 min, writes to SSD)
HandleLidSwitch=suspend-then-hibernate
# On AC power: keep fast RAM suspend
HandleLidSwitchExternalPower=suspend
# Power key triggers smart sleep
HandlePowerKey=suspend-then-hibernate
EOF

echo "=== [3/3] Backpack Wakeup Suppression Service (PCIe/ACPI Fix) ==="
# Prevent GPP6 and GPP7 (Wi-Fi and SD reader) from generating spurious wakeups
sudo tee /etc/systemd/system/disable-sleep-wakeups.service > /dev/null << 'EOF'
[Unit]
Description=Disable unwanted PCIe/ACPI wakeups (Wi-Fi and SD reader) during sleep
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for dev in GPP6 GPP7; do if grep -q "^$dev.*enabled" /proc/acpi/wakeup; then echo "$dev" > /proc/acpi/wakeup; fi; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now disable-sleep-wakeups.service

# Apply immediately to currently running session
for dev in GPP6 GPP7; do
    if grep -q "^$dev.*enabled" /proc/acpi/wakeup 2>/dev/null; then
        echo "Disabling ACPI wakeup source: $dev"
        sudo sh -c "echo $dev > /proc/acpi/wakeup"
    fi
done

echo "-> Mac-style sleep & SSD suspend-then-hibernate settings successfully applied!"
