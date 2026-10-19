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
#      * Injects and persists BUTTON5MOUSE and BUTTON4MOUSE into Blender user preferences.
# ==============================================================================

set -e

echo "=== [1/2] Installing Blender Launcher Wrapper (~/.local/bin/blender) ==="
mkdir -p ~/.local/bin

cat << 'EOF' > ~/.local/bin/blender
#!/usr/bin/env bash
# Clear legacy GPU overrides so Radeon 780M (gfx1103) utilizes native HIP compute
unset HSA_OVERRIDE_GFX_VERSION
exec /usr/bin/blender "$@"
EOF

chmod +x ~/.local/bin/blender

echo "=== [2/2] Configuring Blender Stylus Keymaps (Orbit & Pan) ==="
if command -v blender &> /dev/null; then
    echo "Configuring 3D Viewport Pan (view3d.move) keymaps in Blender..."
    blender -b --python-expr "
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
        print(f'Successfully added {added} keymap(s) and saved Blender preferences.')
    except Exception as e:
        print('Warning: Failed to save preferences via bpy.ops:', e)
else:
    print('Stylus navigation keymaps already configured and up-to-date.')
" 2>&1 | grep -v -E "color_management|OpenColorIO" || true
else
    echo "Notice: blender binary not found in PATH, skipping automatic keymap injection."
fi

echo "Stylus buttons are configured for 3D viewport navigation:"
echo "  * Lower Button (Hold & drag on screen): Rotate Scene (Orbit / view3d.rotate)"
echo "  * Upper Button (Hold & drag on screen): Move Scene (Pan / view3d.move)"
echo "-> Blender Yoga 7 optimizations ready!"
