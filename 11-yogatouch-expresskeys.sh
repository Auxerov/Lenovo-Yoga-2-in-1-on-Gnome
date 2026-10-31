#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 11-yogatouch-expresskeys.sh
# 
# Functionality:
# - Installs and configures YogaTouch: PureRef-style Floating ExpressKeys &
#   Multi-Touch Gesture Suite for Lenovo Yoga 7 2-in-1.
# - Key Features:
#   1. 4-and-5-Finger Pinch-Inward Gesture ("4-5 parmakla ortaya çekme / büzme"):
#      * High-accuracy detection of 4-to-5 finger contraction gestures on touchscreen
#        (Wacom Finger /dev/input/event7) and touchpad (ELAN Touchpad /dev/input/event5)
#        with live contraction & lift-off evaluation to seamlessly toggle overlay.
#   2. PureRef-Style Floating Window:
#      * Always on Top (_NET_WM_STATE_ABOVE / WindowStaysOnTopHint).
#      * Non-focus-stealing (WindowDoesNotAcceptFocus & NoFocus buttons).
#      * Allows simultaneous stylus/mouse drawing while left finger taps touch buttons!
#      * Mouse wheel opacity adjustment (20% to 100%).
#      * Draggable anywhere, defaults and snaps to Top-Right corner.
#   3. Direct Kernel UInput Keystroke & Modifier Emitter:
#      * Momentary Hold and Toggle Latch modes for Shift, Ctrl, Alt, Space, etc.
#      * Instant Tap execution for Undo (Ctrl+Z), Redo, Brush, Eraser, etc.
#   4. YAML-Based Customization (~/.config/yogatouch/config.yaml):
#      * Fully customizable via human-readable YAML config with live auto-reload.
#      * In-app GUI settings modal with integrated YAML editor & validator.
#      * Clean typography with zero emojis and no Pan/Orbit buttons.
#   5. Autostart & Fallback Hotkey:
#      * Registered systemd user service (yogatouch.service).
#      * Registered GNOME custom shortcut: Super+O to toggle.
# ==============================================================================

set -e

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="${SCRIPT_DIR}/resources/yogatouch"
APP_DIR="${HOME}/.local/share/yogatouch"
BIN_DIR="${HOME}/.local/bin"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/scalable/apps"
SYSTEMD_USER_DIR="${HOME}/.config/systemd/user"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}       YogaTouch: Floating ExpressKeys & 4-to-5 Finger Gesture Suite          ${NC}"
echo -e "${BLUE}                        Author: Auxerov                                       ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# 1. Dependency Check
echo -e "${YELLOW}[1/5] Checking dependencies (Python3, evdev, PyQt6, PyYAML)...${NC}"
MISSING_PKGS=()
if ! python3 -c "import evdev" &>/dev/null; then
    MISSING_PKGS+=("python3-evdev")
fi
if ! python3 -c "from PyQt6.QtWidgets import QApplication" &>/dev/null; then
    MISSING_PKGS+=("python3-pyqt6")
fi
if ! python3 -c "import yaml" &>/dev/null; then
    MISSING_PKGS+=("python3-pyyaml")
fi

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo -e "${YELLOW}  Installing missing packages: ${MISSING_PKGS[*]}...${NC}"
    sudo dnf install -y "${MISSING_PKGS[@]}"
else
    echo -e "${GREEN}  ✓ Python dependencies (evdev, PyQt6, PyYAML) are installed.${NC}"
fi

# Ensure user is in input group
if ! groups "$USER" | grep -q "\binput\b"; then
    echo -e "${YELLOW}  Adding $USER to 'input' group for /dev/input access...${NC}"
    sudo usermod -aG input "$USER"
fi

# 2. Deploy Application Files
echo ""
echo -e "${YELLOW}[2/5] Deploying YogaTouch files...${NC}"
mkdir -p "${APP_DIR}" "${BIN_DIR}" "${DESKTOP_DIR}" "${ICON_DIR}" "${SYSTEMD_USER_DIR}"

cp -rf "${RESOURCES_DIR}"/* "${APP_DIR}/" 2>/dev/null || true
rm -rf "${APP_DIR}/__pycache__"

# Create / update wrapper in ~/.local/bin/yogatouch
cat << 'EOF' > "${BIN_DIR}/yogatouch"
#!/usr/bin/env bash
exec python3 /home/auxerov/.local/share/yogatouch/yogatouch.py "$@"
EOF
chmod +x "${BIN_DIR}/yogatouch"
echo -e "${GREEN}  ✓ Installed CLI wrapper to ${BIN_DIR}/yogatouch${NC}"

# Deploy Icon & Desktop Entry
if [ -f "${RESOURCES_DIR}/yogatouch.svg" ]; then
    cp -f "${RESOURCES_DIR}/yogatouch.svg" "${ICON_DIR}/"
fi
if [ -f "${RESOURCES_DIR}/yogatouch.desktop" ]; then
    cp -f "${RESOURCES_DIR}/yogatouch.desktop" "${DESKTOP_DIR}/"
    update-desktop-database "${DESKTOP_DIR}" 2>/dev/null || true
fi
echo -e "${GREEN}  ✓ Installed desktop entry & vector icon${NC}"

# 3. Configure GNOME Keyboard Shortcut (Super+O)
echo ""
echo -e "${YELLOW}[3/5] Configuring GNOME shortcut (Super+O)...${NC}"
python3 -c "
import subprocess
try:
    out = subprocess.check_output(['gsettings', 'get', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings']).decode().strip()
    bindings = eval(out) if out.startswith('[') else []
    path = '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom5/'
    if path not in bindings:
        bindings.append(path)
        subprocess.check_call(['gsettings', 'set', 'org.gnome.settings-daemon.plugins.media-keys', 'custom-keybindings', str(bindings)])
    schema = f'org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:{path}'
    subprocess.check_call(['gsettings', 'set', schema, 'name', 'YogaTouch ExpressKeys'])
    subprocess.check_call(['gsettings', 'set', schema, 'command', '${BIN_DIR}/yogatouch --toggle'])
    subprocess.check_call(['gsettings', 'set', schema, 'binding', '<Super>o'])
    print('  ✓ Registered Super+O keyboard shortcut.')
except Exception as e:
    print('  ! Note setting shortcut:', e)
"

# 4. Configure Systemd User Service
echo ""
echo -e "${YELLOW}[4/5] Setting up systemd user service...${NC}"
cat << EOF > "${SYSTEMD_USER_DIR}/yogatouch.service"
[Unit]
Description=YogaTouch Floating ExpressKeys & Multi-Touch Gesture Monitor
After=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
ExecStartPre=/usr/bin/sleep 1.5
ExecStart=${BIN_DIR}/yogatouch
Restart=on-failure
RestartSec=3s
Environment=QT_QPA_PLATFORM=xcb
Environment=QT_AUTO_SCREEN_SCALE_FACTOR=1
Environment=QT_ENABLE_HIGHDPI_SCALING=1
Environment=QT_SCALE_FACTOR_ROUNDING_POLICY=PassThrough

[Install]
WantedBy=graphical-session.target
EOF

systemctl --user daemon-reload
systemctl --user enable yogatouch.service
systemctl --user restart yogatouch.service
echo -e "${GREEN}  ✓ YogaTouch service enabled and started in background.${NC}"

# 5. Summary & Verification
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  SUCCESS: YogaTouch ExpressKeys Installed and Running!                      ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "How to use YogaTouch:"
echo -e " 1. 4-to-5 Finger Pinch Inward Gesture ('ortaya çekme / büzme'):"
echo -e "    - Touch 4 or 5 fingers on the screen or touchpad and pull them inward."
echo -e "    - The floating express dock smoothly toggles (appears/disappears)!"
echo -e " 2. Keyboard Shortcut:"
echo -e "    - Press Super + O to toggle at any time."
echo -e " 3. Non-Focus-Stealing Touch Dock:"
echo -e "    - Floats in the top-right corner over Blender, Affinity, Krita, etc."
echo -e "    - Tap or hold buttons with your left hand while drawing with stylus in your right hand!"
echo -e "    - Never steals window focus or interrupts brush strokes."
echo -e " 4. YAML Configuration & Customization:"
echo -e "    - Config file: ~/.config/yogatouch/config.yaml"
echo -e "    - Click 'CFG' or right-click to open Settings & YAML Editor."
echo -e "    - Fully customizable profiles, key combinations, and live auto-reload."
echo -e " 5. PureRef Opacity:"
echo -e "    - Scroll your mouse wheel over the dock to adjust transparency (20% to 100%)."
echo ""
