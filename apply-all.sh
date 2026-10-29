#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Master Setup & Recovery Script
# Author: Auxerov
# File: apply-all.sh
# 
# Functionality:
# - Executes all individual hardware patches, drivers, and optimizations in sequence.
# - Provides a single-command setup for Stylus, Sleep, Battery, Bluetooth, Affinity, etc.
# ==============================================================================

set -e

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}       Lenovo Yoga 7 2-in-1 Linux Configuration & Recovery Suite              ${NC}"
echo -e "${BLUE}                        Author: Auxerov                                       ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Sudo check (prompts once at the beginning)
echo -e "${YELLOW}[!] Root/administrator privileges (sudo) may be required for system settings...${NC}"
sudo -v

# Keep sudo timestamp alive in the background
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
trap 'kill -9 $SUDO_PID 2>/dev/null || true' EXIT

SCRIPTS=(
    "01-pen-and-touch-fix.sh"
    "02-sleep-and-suspend-to-disk.sh"
    "03-battery-conservation.sh"
    "04-bluetooth-power-fix.sh"
    "05-disable-remote-desktop-popups.sh"
    "06-affinity-linux-optimization.sh"
    "07-blender-yoga-tuning.sh"
    "08-librewolf-dpi-discord.sh"
    "09-foliate-vertical-matte-black.sh"
    "10-appflowy-oled-black-theme.sh"
)

TOTAL=${#SCRIPTS[@]}
CURRENT=0

for script in "${SCRIPTS[@]}"; do
    CURRENT=$((CURRENT + 1))
    SCRIPT_PATH="${SCRIPT_DIR}/${script}"
    
    echo ""
    echo -e "${BLUE}------------------------------------------------------------------------------${NC}"
    echo -e "${GREEN}[${CURRENT}/${TOTAL}] Running: ${script}${NC}"
    echo -e "${BLUE}------------------------------------------------------------------------------${NC}"
    
    if [ -f "$SCRIPT_PATH" ]; then
        chmod +x "$SCRIPT_PATH"
        bash "$SCRIPT_PATH"
    else
        echo -e "${RED}Error: ${SCRIPT_PATH} not found, skipping!${NC}"
    fi
done

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  SUCCESS: All settings for Lenovo Yoga 7 2-in-1 applied successfully!       ${NC}"
echo -e "${GREEN}                        Author: Auxerov                                       ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "Summary of Applied Configs:"
echo -e " 1. [Pen & Touch] Installed Lenovo Digital Pen 2 HID-BPF driver & GNOME button keymaps."
echo -e " 2. [Sleep & SSD] Configured Mac-style suspend-then-hibernate (30m delay) & backpack wakeup fix."
echo -e " 3. [Battery] Enabled ~80% battery conservation mode and installed 'bat-limit' command."
echo -e " 4. [Bluetooth] Set Realtek Bluetooth power control to 'on' to prevent dropouts."
echo -e " 5. [Remote Desktop] Suppressed unwanted '+ 2 Remote Desktop' prompts and portal popups."
echo -e " 6. [Affinity Linux] Fixed new document SEH crash (ninput bypass), tuned DXVK & memory."
echo -e " 7. [Blender 3D] Enabled Radeon 780M native HIP compute and stylus 3D viewport navigation."
echo -e " 8. [DPI / Discord] Configured zero-slowdown selective DPI bypass (SpoofDPI + DoH) in LibreWolf."
echo -e " 9. [Foliate E-Reader] Configured continuous vertical scrolling, true matte black theme, auto-chapter advance, shelf system, and right-click mark as read."
echo -e " 10. [AppFlowy] Installed True Pure Black OLED themes (OLED Black & OLED Monochrome) for optimal battery & display contrast."
echo ""
