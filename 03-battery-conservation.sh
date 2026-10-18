#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 03-battery-conservation.sh
# 
# Functionality:
# - Lenovo Battery Conservation Mode:
#   * Keeping lithium-ion cells at 100% state-of-charge causes chemical degradation.
#   * Caps charging around 80% to maximize overall battery health and lifespan.
#   * Before traveling, you can run 'bat-limit off' to allow charging to 100%.
# - 'bat-limit' Command-line Utility:
#   * bat-limit on     -> Caps charging around 80% (Conservation Mode)
#   * bat-limit off    -> Allows full charging up to 100%
#   * bat-limit status -> Shows current charge percentage and conservation mode status
# ==============================================================================

set -e

echo "=== [1/2] Installing 'bat-limit' CLI Tool ==="
sudo tee /usr/local/bin/bat-limit > /dev/null << 'EOF'
#!/usr/bin/env bash
CONV_FILE=$(find /sys/devices/ -name conservation_mode 2>/dev/null | head -n 1)

if [ -z "$CONV_FILE" ]; then
  echo "Error: Lenovo battery conservation mode sysfs entry not found."
  exit 1
fi

case "${1:-status}" in
  on|enable|80|85)
    echo 1 | sudo tee "$CONV_FILE" > /dev/null
    echo "Battery Conservation Mode ENABLED. Charging will stop around ~80%."
    ;;
  off|disable|100)
    echo 0 | sudo tee "$CONV_FILE" > /dev/null
    echo "Battery Conservation Mode DISABLED. Charging will continue up to 100%."
    ;;
  status|info)
    VAL=$(cat "$CONV_FILE")
    CAP=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || echo "?")
    STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || echo "?")
    echo "Current Battery Level: ${CAP}% (${STATUS})"
    if [ "$VAL" -eq 1 ]; then
      echo "Conservation Mode: ACTIVE (Charge capped at ~80% to protect battery health)"
    else
      echo "Conservation Mode: INACTIVE (Full 100% charge permitted)"
    fi
    ;;
  *)
    echo "Usage: bat-limit [on|off|status]"
    echo "  bat-limit on     : Stops charging at ~80% (preserves battery longevity)"
    echo "  bat-limit off    : Charges up to 100% (ideal before traveling)"
    echo "  bat-limit status : Displays current battery status and mode"
    ;;
esac
EOF

sudo chmod +x /usr/local/bin/bat-limit

echo "=== [2/2] Systemd Boot-time Auto-enable Service ==="
sudo tee /etc/systemd/system/lenovo-battery-conservation.service > /dev/null << 'EOF'
[Unit]
Description=Lenovo Battery Conservation Mode (Caps charge around 80% to extend lifespan)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'F=$(find /sys/devices/ -name conservation_mode 2>/dev/null | head -n 1); if [ -n "$F" ]; then echo 1 > "$F"; fi'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now lenovo-battery-conservation.service

# Apply immediately
/usr/local/bin/bat-limit on || true

echo "-> Lenovo Battery Conservation Mode successfully installed and enabled (~80% cap)!"
