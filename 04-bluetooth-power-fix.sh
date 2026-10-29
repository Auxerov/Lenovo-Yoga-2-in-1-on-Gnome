#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 04-bluetooth-power-fix.sh
# 
# Functionality:
# - Comprehensive Realtek RTL8852CE (0bda:5852) Wi-Fi/Bluetooth Audio Stutter Fix:
#   1. Resolves Realtek Firmware Regression:
#      * Linux 6.12+ kernels load rtw8852c_fw-2 / fw-1 which have a known,
#        critical coexistence bug causing Wi-Fi packets to choke Bluetooth audio,
#        triggering "Missing completion reports for packet" and audio stuttering.
#      * Safely disables -2 and -1 variants to fall back to the rock-solid base
#        rtw8852c_fw.bin (0.27.56.14) without breaking Wi-Fi or Bluetooth.
#   2. Kernel Module & Power Management Tuning:
#      * Disables btusb USB autosuspend (enable_autosuspend=n).
#      * Disables Wi-Fi low power mode (disable_ps_mode=y in rtw89_core) to stop
#        cyclic radio power-down bursts that starve Bluetooth bandwidth.
#      * Disables PCIe ASPM L1/L1SS sleep transitions (rtw89_pci) to eliminate
#        queue flush timeouts and DCK errors.
#   3. NetworkManager Wi-Fi Powersave:
#      * Disables Wi-Fi power saving (wifi.powersave = 2) to eliminate RF jitter.
#   4. BlueZ Connection Optimization:
#      * Enables FastConnectable and JustWorksRepairing in /etc/bluetooth/main.conf.
#   5. WirePlumber / PipeWire Bluetooth Audio Priority:
#      * Elevates BlueZ audio stream priority (priority.driver=2000).
#      * Disables autoswitch to low-quality HFP/HSP mono speech when apps query mic.
# ==============================================================================

set -e

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== [1/6] Disabling Buggy Realtek RTL8852CE Firmware Variants ===${NC}"
RTW89_FW_DIR="/lib/firmware/rtw89"
if [ -d "${RTW89_FW_DIR}" ]; then
    # Disable rtw8852c_fw-2.bin(.xz)
    for f in "${RTW89_FW_DIR}"/rtw8852c_fw-2.bin*; do
        if [ -f "$f" ] && [[ "$f" != *.disabled ]]; then
            echo -e "${YELLOW}[!] Disabling buggy firmware: $f${NC}"
            sudo mv "$f" "${f}.disabled"
        fi
    done

    # Disable rtw8852c_fw-1.bin(.xz)
    for f in "${RTW89_FW_DIR}"/rtw8852c_fw-1.bin*; do
        if [ -f "$f" ] && [[ "$f" != *.disabled ]]; then
            echo -e "${YELLOW}[!] Disabling buggy firmware: $f${NC}"
            sudo mv "$f" "${f}.disabled"
        fi
    done

    echo -e "${GREEN}[✓] Firmware fallback to stable rtw8852c_fw.bin configured.${NC}"
fi

echo -e "${BLUE}=== [2/6] Configuring Kernel Module Options (btusb & rtw89) ===${NC}"
sudo tee /etc/modprobe.d/50-realtek-bluetooth-coex.conf > /dev/null << 'EOF'
# Disable Bluetooth USB autosuspend
options btusb enable_autosuspend=n

# Realtek Wi-Fi and Bluetooth coexistence stability
options rtw89_core disable_ps_mode=y
options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y
EOF
echo -e "${GREEN}[✓] /etc/modprobe.d/50-realtek-bluetooth-coex.conf created.${NC}"

echo -e "${BLUE}=== [3/6] Installing Bluetooth Udev Power Rule ===${NC}"
sudo tee /etc/udev/rules.d/50-bluetooth-power.rules > /dev/null << 'EOF'
ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bda", ATTR{idProduct}=="5852", ATTR{power/control}="on"
EOF
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
                echo -e "${GREEN}[✓] Set Bluetooth power control to 'on': $dev${NC}"
            fi
        fi
    fi
done

echo -e "${BLUE}=== [4/6] Disabling NetworkManager Wi-Fi Powersave ===${NC}"
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/default-wifi-powersave-off.conf > /dev/null << 'EOF'
[connection]
wifi.powersave = 2
EOF
echo -e "${GREEN}[✓] NetworkManager Wi-Fi power saving disabled.${NC}"

echo -e "${BLUE}=== [5/6] Tuning BlueZ Bluetooth Daemon Settings ===${NC}"
if [ -f /etc/bluetooth/main.conf ]; then
    # Ensure FastConnectable = true
    if grep -q "^#FastConnectable = false" /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#FastConnectable = false/FastConnectable = true/' /etc/bluetooth/main.conf
    elif ! grep -q "^FastConnectable = true" /etc/bluetooth/main.conf; then
        sudo sed -i '/^\[General\]/a FastConnectable = true' /etc/bluetooth/main.conf
    fi

    # Ensure JustWorksRepairing = always
    if grep -q "^#JustWorksRepairing = never" /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#JustWorksRepairing = never/JustWorksRepairing = always/' /etc/bluetooth/main.conf
    elif ! grep -q "^JustWorksRepairing = always" /etc/bluetooth/main.conf; then
        sudo sed -i '/^\[General\]/a JustWorksRepairing = always' /etc/bluetooth/main.conf
    fi
    echo -e "${GREEN}[✓] /etc/bluetooth/main.conf tuned.${NC}"
fi

echo -e "${BLUE}=== [6/6] Configuring WirePlumber Bluetooth Audio Priority ===${NC}"
USER_WP_DIR="${HOME}/.config/wireplumber/wireplumber.conf.d"
mkdir -p "${USER_WP_DIR}"
cat << 'EOF' > "${USER_WP_DIR}/50-bluez-tuning.conf"
monitor.bluez.properties = {
  bluez5.enable-sbc-xq = true
  bluez5.enable-msbc = true
  bluez5.autoswitch-routes = false
}

monitor.bluez.rules = [
  {
    matches = [
      {
        device.name = "~bluez_card.*"
      }
    ]
    actions = {
      update-props = {
        bluez5.autoswitch-routes = false
      }
    }
  }
  {
    matches = [
      {
        node.name = "~bluez_output.*"
      }
    ]
    actions = {
      update-props = {
        priority.driver = 2000
        priority.session = 2000
        node.pause-on-idle = false
      }
    }
  }
]
EOF

systemctl --user restart wireplumber 2>/dev/null || true
echo -e "${GREEN}[✓] WirePlumber Bluetooth audio priority configured and restarted.${NC}"

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  Realtek Bluetooth & Wi-Fi Coexistence Fix Applied Successfully!             ${NC}"
echo -e "${YELLOW}  Note: A system reboot is recommended for firmware & module changes to take   ${NC}"
echo -e "${YELLOW}        full effect on the Realtek radio controller.                           ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
