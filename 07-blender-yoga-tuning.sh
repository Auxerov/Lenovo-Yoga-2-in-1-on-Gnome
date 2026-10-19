#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 07-blender-yoga-tuning.sh
# 
# Functionality:
# - Blender AMD Radeon 780M (ROCm/HIP) & Yoga Stylus Navigation:
#   1. Radeon 780M RDNA3 (gfx1103) Acceleration:
#      * Clears legacy HSA_OVERRIDE_GFX_VERSION environment variable so Blender
#        uses modern, native HIP compute kernels directly on Linux.
#   2. Stylus 3D Viewport Navigation:
#      * Lower Barrel Button (Middle Click) -> Orbit 3D Viewport (view3d.rotate)
#      * Upper Barrel Button (Button 5 / Forward) -> Pan 3D Viewport (view3d.move / Shift + Middle Click)
#      * Forces XWayland mode (WAYLAND_DISPLAY="") so GNOME reliably delivers Button 5
#        events without tablet tool drop issues in both system and Steam Blender.
#      * Injects and persists BUTTON5MOUSE and BUTTON4MOUSE into Blender user preferences.
# ==============================================================================

set -e

echo "=== [1/3] Installing System Blender Launcher Wrapper (~/.local/bin/blender) ==="
mkdir -p ~/.local/bin

cat << 'EOF' > ~/.local/bin/blender
#!/usr/bin/env bash
# Clear legacy GPU overrides so Radeon 780M (gfx1103) utilizes native HIP compute
unset HSA_OVERRIDE_GFX_VERSION

# Force XWayland for rock-solid stylus middle-click and button 5 navigation
export WAYLAND_DISPLAY=""

exec /usr/bin/blender "$@"
EOF

chmod +x ~/.local/bin/blender

echo "=== [2/3] Configuring Steam Blender Wrapper ==="
STEAM_BLENDER_DIR="$HOME/.local/share/Steam/steamapps/common/Blender"
if [ -d "$STEAM_BLENDER_DIR" ]; then
    if [ ! -f "$STEAM_BLENDER_DIR/blender.bin" ] && [ -f "$STEAM_BLENDER_DIR/blender" ]; then
        mv "$STEAM_BLENDER_DIR/blender" "$STEAM_BLENDER_DIR/blender.bin"
    fi

    cat << 'EOF' > "$STEAM_BLENDER_DIR/blender"
#!/usr/bin/env bash
# Steam Blender Wrapper - Force XWayland for seamless stylus navigation (Orbit & Pan)

DIR="$(dirname "$(readlink -f "$0")")"

# Force XWayland so GNOME forwards stylus upper barrel button (Forward/BUTTON5MOUSE -> Pan)
export WAYLAND_DISPLAY=""

# Ensure bundled libraries are prioritized
if [ -d "$DIR/lib" ]; then
    export LD_LIBRARY_PATH="$DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi

# Clear legacy GPU overrides so Radeon 780M (gfx1103) utilizes native HIP compute
unset HSA_OVERRIDE_GFX_VERSION

exec "$DIR/blender.bin" "$@"
EOF
    chmod +x "$STEAM_BLENDER_DIR/blender"
    echo "Steam Blender wrapper successfully configured at $STEAM_BLENDER_DIR/blender"
else
    echo "Notice: Steam Blender directory not found, skipping."
fi

echo "=== [3/3] Configuring Blender Stylus Keymaps (Orbit & Pan) ==="
# Helper python function to inject navigation keymaps into a given Blender config dir
inject_keymaps() {
    local blender_bin="$1"
    local config_dir="$2"
    if [ -x "$blender_bin" ]; then
        echo "Injecting keymaps using $blender_bin (config: $config_dir)..."
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
        print(f'Successfully added {added} keymap(s) to userpref.blend.')
    except Exception as e:
        print('Warning: Failed to save preferences via bpy.ops:', e)
else:
    print('Keymaps already up-to-date.')
" 2>&1 | grep -v -E "color_management|OpenColorIO" || true
    fi
}

# Determine available Blender executable
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
        fi
    done
else
    echo "Notice: No blender binary found, skipping keymap injection."
fi

echo "Stylus buttons are configured for 3D viewport navigation:"
echo "  * Lower Button (Hold & drag on screen): Rotate Scene (Orbit / view3d.rotate)"
echo "  * Upper Button (Hold & drag on screen): Move Scene (Pan / view3d.move / Shift + Middle Click)"
echo "-> Blender Yoga 7 optimizations ready!"
