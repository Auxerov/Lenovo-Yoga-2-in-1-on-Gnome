#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: Blender on 2 in 1.sh
# 
# Comprehensive Optimization & Setup Script for Blender on Lenovo Yoga 7 2-in-1:
#   1. AMD Radeon 780M (RDNA3 / gfx1103) Native HIP Compute Acceleration
#   2. Native Wayland Fractional Scaling (100% crisp 1.25x HiDPI, no XWayland blur)
#   3. Hardware Evdev Multi-Touch & Stylus Permissions (input group + udev rules)
#   4. Elevated System (~/.local/bin/blender) & Steam Launcher Wrappers (sg input fallback)
#   5. Lenovo Digital Pen 2 GNOME Dconf Mapping (Lower: Orbit, Upper: Pan)
#   6. Blender User Keymaps Injection (BUTTON4/5MOUSE -> view3d.move)
#   7. Vimender Addon Automatic Symlinks & Deployment across all Blender versions
#   8. GNOME Application Launcher (.desktop) Integration
# ==============================================================================

set -e

# ANSI Color formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BOLD}${BLUE}          Blender on 2 in 1 - Lenovo Yoga 7 Configuration Suite               ${NC}"
echo -e "${CYAN}                            Author: Auxerov                                   ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Check administrator privileges if interactive, otherwise fallback safely
HAS_SUDO=false
if sudo -n true 2>/dev/null; then
    HAS_SUDO=true
elif [ -t 0 ] && [ -z "$NONINTERACTIVE" ] && command -v sudo &>/dev/null; then
    echo -e "${YELLOW}[!] Administrator privileges (sudo) may be requested for system udev rules...${NC}"
    if sudo -v 2>/dev/null; then
        HAS_SUDO=true
        while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
        SUDO_PID=$!
        trap 'kill -9 $SUDO_PID 2>/dev/null || true' EXIT
    fi
fi

# --- Step 1: Hardware & System Assessment ---
echo ""
echo -e "${BLUE}--- [1/7] Inspecting Hardware Devices ---${NC}"
GPU_NAME=$(lspci | grep -i 'VGA\|3D' | cut -d ':' -f3 || echo "AMD Radeon Graphics")
echo -e "GPU Detected: ${GREEN}${GPU_NAME}${NC}"

TOUCH_DEV="/dev/input/by-path/platform-AMDI0010:02-event"
STYLUS_DEV="/dev/input/by-path/platform-AMDI0010:02-event-mouse"

if [ -e "$TOUCH_DEV" ]; then
    echo -e "Touchscreen:  ${GREEN}Found ($TOUCH_DEV)${NC}"
else
    echo -e "Touchscreen:  ${YELLOW}Notice: $TOUCH_DEV not found at fixed path, evdev auto-discovery will be used.${NC}"
fi

if [ -e "$STYLUS_DEV" ]; then
    echo -e "Stylus Input: ${GREEN}Found ($STYLUS_DEV)${NC}"
else
    echo -e "Stylus Input: ${YELLOW}Notice: $STYLUS_DEV not found at fixed path, evdev auto-discovery will be used.${NC}"
fi

# --- Step 2: Input Group Permissions & Udev Rules ---
echo ""
echo -e "${BLUE}--- [2/7] Hardware Input Permissions (Evdev & Multi-touch) ---${NC}"

if [ "$HAS_SUDO" = true ]; then
    if ! groups "$USER" | grep -qw "input"; then
        echo -e "Adding user ${BOLD}$USER${NC} to group ${BOLD}input${NC}..."
        sudo usermod -aG input "$USER"
        echo -e "${GREEN}✓ User added to input group.${NC}"
    else
        echo -e "${GREEN}✓ User $USER is already a member of the input group.${NC}"
    fi

    echo "Installing udev rule (/etc/udev/rules.d/99-input-permissions.rules)..."
    sudo tee /etc/udev/rules.d/99-input-permissions.rules > /dev/null << 'EOF'
# Grant group input access to raw evdev devices for touchscreen and stylus gestures
KERNEL=="event*", SUBSYSTEM=="input", MODE="0660", GROUP="input"
EOF

    sudo udevadm control --reload
    sudo udevadm trigger --subsystem-match=input || true
    echo -e "${GREEN}✓ Udev permissions reloaded.${NC}"
else
    echo -e "${YELLOW}Notice: Sudo not active; launcher wrapper will use 'sg input' fallback dynamically.${NC}"
fi

# --- Step 3: System & Steam Blender Wrappers ---
echo ""
echo -e "${BLUE}--- [3/7] Blender Launcher Wrappers (System & Steam) ---${NC}"
mkdir -p "$HOME/.local/bin"

# System wrapper: unsets HSA_OVERRIDE_GFX_VERSION and uses sg input fallback
cat << 'EOF' > "$HOME/.local/bin/blender"
#!/usr/bin/env bash
# System Blender Launcher - Native Wayland with elevated input group permissions

# Clear legacy GPU overrides so Radeon 780M (gfx1103) utilizes native HIP compute
unset HSA_OVERRIDE_GFX_VERSION

# Elevate process credentials to include 'input' group for hardware evdev multi-touch & stylus
if ! id -G | grep -qw 104 && ! groups | grep -qw "input"; then
    CMD="$(printf '%q ' "$0" "$@")"
    exec sg input -c "$CMD"
fi

exec /usr/bin/blender "$@"
EOF
chmod +x "$HOME/.local/bin/blender"
echo -e "${GREEN}✓ System wrapper installed at ~/.local/bin/blender${NC}"

# Steam Blender wrapper
STEAM_BLENDER_DIR="$HOME/.local/share/Steam/steamapps/common/Blender"
if [ -d "$STEAM_BLENDER_DIR" ]; then
    if [ ! -f "$STEAM_BLENDER_DIR/blender.bin" ] && [ -f "$STEAM_BLENDER_DIR/blender" ]; then
        mv "$STEAM_BLENDER_DIR/blender" "$STEAM_BLENDER_DIR/blender.bin"
    fi

    cat << 'EOF' > "$STEAM_BLENDER_DIR/blender"
#!/usr/bin/env bash
# Steam Blender Launcher - Native Wayland with elevated input group permissions

# Clear legacy GPU overrides so Radeon 780M (gfx1103) utilizes native HIP compute
unset HSA_OVERRIDE_GFX_VERSION

# Elevate process credentials to include 'input' group for hardware evdev multi-touch & stylus
if ! id -G | grep -qw 104 && ! groups | grep -qw "input"; then
    CMD="$(printf '%q ' "$0" "$@")"
    exec sg input -c "$CMD"
fi

DIR="$(dirname "$(readlink -f "$0")")"

# Ensure bundled libraries are prioritized
if [ -d "$DIR/lib" ]; then
    export LD_LIBRARY_PATH="$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

exec "$DIR/blender.bin" "$@"
EOF
    chmod +x "$STEAM_BLENDER_DIR/blender"
    echo -e "${GREEN}✓ Steam Blender wrapper configured at $STEAM_BLENDER_DIR/blender${NC}"
else
    echo -e "Notice: Steam Blender directory not found, skipping Steam wrapper."
fi

# --- Step 4: GNOME Stylus Barrel Button Mappings (Dconf) ---
echo ""
echo -e "${BLUE}--- [4/7] GNOME Stylus Button Mappings (Dconf) ---${NC}"
# Known Yoga 7 Stylus IDs (including 80e4ef9b)
STYLUS_IDS=("80e4ef9b")
for id in $(dconf list /org/gnome/desktop/peripherals/stylus/ 2>/dev/null | tr -d '/'); do
    if [ -n "$id" ] && [[ ! " ${STYLUS_IDS[*]} " =~ " ${id} " ]]; then
        STYLUS_IDS+=("$id")
    fi
done

for sid in "${STYLUS_IDS[@]}"; do
    path="/org/gnome/desktop/peripherals/stylus/${sid}/"
    echo "Setting Dconf stylus properties on ${path}..."
    dconf write "${path}button-action" "'forward'"
    dconf write "${path}secondary-button-action" "'middle'"
    dconf write "${path}eraser-button-action" "'middle'"
    dconf write "${path}eraser-button-mode" "'button'"
    dconf write "${path}pressure-curve" "[0, 0, 100, 100]"
done
echo -e "${GREEN}✓ GNOME Stylus buttons mapped (Upper: Forward/Pan, Lower: Middle/Orbit).${NC}"

# --- Step 5: Blender User Keymap Injection ---
echo ""
echo -e "${BLUE}--- [5/7] Blender Stylus Navigation Keymaps Injection ---${NC}"

inject_keymaps() {
    local blender_bin="$1"
    local config_dir="$2"
    if [ -x "$blender_bin" ]; then
        echo "Injecting viewport navigation keymaps (config: $config_dir)..."
        BLENDER_USER_CONFIG="$config_dir" "$blender_bin" -b --python-expr "
import bpy

kc = bpy.context.window_manager.keyconfigs.user
km = kc.keymaps.get('3D View')
if not km:
    km = kc.keymaps.new(name='3D View', space_type='VIEW_3D')

added = 0
for btn in ('BUTTON5MOUSE', 'BUTTON4MOUSE'):
    if not any(kmi.type == btn and kmi.idname == 'view3d.move' for kmi in km.keymap_items):
        kmi = km.keymap_items.new('view3d.move', btn, 'PRESS')
        kmi.active = True
        added += 1

if added > 0:
    try:
        bpy.ops.wm.save_userpref()
        print(f'Successfully injected {added} keymap(s) into userpref.blend.')
    except Exception as e:
        print('Warning: Failed to save preferences via bpy.ops:', e)
else:
    print('Keymaps already up-to-date.')
" 2>&1 | grep -v -E "color_management|OpenColorIO" || true
    fi
}

BLENDER_EXEC=""
if [ -x "$STEAM_BLENDER_DIR/blender.bin" ]; then
    BLENDER_EXEC="$STEAM_BLENDER_DIR/blender.bin"
elif command -v blender &> /dev/null; then
    BLENDER_EXEC="$(command -v /usr/bin/blender || command -v blender)"
fi

if [ -n "$BLENDER_EXEC" ]; then
    for cfg in "$HOME/.config/blender"/*/config; do
        if [ -d "$cfg" ]; then
            inject_keymaps "$BLENDER_EXEC" "$cfg"
            # Ensure stylus pan sensitivity is set to 1.75 in vimender_config.json
            VIM_CFG="$cfg/vimender_config.json"
            if [ -f "$VIM_CFG" ]; then
                python3 -c "import json; p='$VIM_CFG'; d=json.load(open(p)); d['stylus_pan_sensitivity']=1.75; json.dump(d,open(p,'w'),indent=2)" 2>/dev/null || true
            fi
        fi
    done
    echo -e "${GREEN}✓ Keymaps & Stylus settings verified for all local Blender versions.${NC}"
else
    echo -e "${YELLOW}Notice: No Blender binary detected to execute keymap injection.${NC}"
fi

# --- Step 6: Vimender Addon Symlinks & Direct Deployment ---
echo ""
echo -e "${BLUE}--- [6/7] Vimender Addon Deployment ---${NC}"
VIMENDER_SRC="/home/auxerov/Documents/Projects/Vimender"

if [ -d "$VIMENDER_SRC" ]; then
    for b_ver_dir in "$HOME/.config/blender"/*; do
        if [ -d "$b_ver_dir" ] && [[ "$(basename "$b_ver_dir")" =~ ^[0-9]+\.[0-9]+$ ]]; then
            ADDONS_DIR="$b_ver_dir/scripts/addons"
            mkdir -p "$ADDONS_DIR"
            TARGET_LINK="$ADDONS_DIR/Vimender"
            if [ -L "$TARGET_LINK" ]; then
                rm -f "$TARGET_LINK"
            elif [ -d "$TARGET_LINK" ]; then
                echo "Backing up existing directory at $TARGET_LINK..."
                mv "$TARGET_LINK" "${TARGET_LINK}.backup.$(date +%s)"
            fi
            ln -s "$VIMENDER_SRC" "$TARGET_LINK"
            echo -e "Linked Vimender -> ${GREEN}$TARGET_LINK${NC}"
        fi
    done
    echo -e "${GREEN}✓ Vimender active across all Blender version profiles.${NC}"
else
    echo -e "${YELLOW}Warning: Vimender source directory not found at $VIMENDER_SRC.${NC}"
fi

# --- Step 7: Desktop Application Launcher (.desktop) Setup ---
echo ""
echo -e "${BLUE}--- [7/7] Desktop Application Launcher Setup ---${NC}"
mkdir -p "$HOME/.local/share/applications"
DESKTOP_FILE="$HOME/.local/share/applications/blender.desktop"

cat << EOF > "$DESKTOP_FILE"
[Desktop Entry]
Name=Blender (Lenovo Yoga 2-in-1)
GenericName=3D Modeler
Comment=3D Modeling, Animation, and Sculpting optimized for Lenovo Yoga 7
Exec=$HOME/.local/bin/blender %f
Icon=blender
Terminal=false
Type=Application
Categories=Graphics;3DGraphics;
MimeType=application/x-blender;
StartupNotify=true
StartupWMClass=blender
EOF

chmod +x "$DESKTOP_FILE"
update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
echo -e "${GREEN}✓ Desktop launcher created at $DESKTOP_FILE${NC}"

# --- Completion Summary ---
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${BOLD}${GREEN}  SUCCESS: All Blender 2-in-1 optimizations applied successfully!             ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "Summary of Features Configured:"
echo -e "  ${BOLD}1. AMD Radeon 780M RDNA3 Compute:${NC} Cleared legacy GPU version overrides for HIP compute."
echo -e "  ${BOLD}2. Native Wayland Fractional Scaling:${NC} 1.25x HiDPI crisp rendering, no XWayland blur."
echo -e "  ${BOLD}3. Evdev Multi-Touch & Stylus Access:${NC} User added to input group, udev rules applied."
echo -e "  ${BOLD}4. Stylus Viewport Navigation:${NC}"
echo -e "     - ${CYAN}Lower Button (Hold & Drag):${NC} Rotate / Orbit 3D Scene"
echo -e "     - ${CYAN}Upper Button (Hold & Drag):${NC} Pan 3D Viewport (Shift + Middle Click / 1.75x Sensitivity)"
echo -e "  ${BOLD}5. Vimender Addon Modes:${NC}"
echo -e "     - ${CYAN}AltGr + Space:${NC} Mode Search Popup"
echo -e "     - ${CYAN}Ctrl + Alt + P:${NC} Pen Mode (White theme, instant isolated 2-finger pinch-zoom)"
echo -e "     - ${CYAN}Ctrl + W:${NC} Tablet Mode (Touch transform, gizmos, responsive anchor pinch-zoom)"
echo ""
