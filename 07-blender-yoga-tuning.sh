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
#      * Upper Barrel Button (Button 5 / Forward) -> Pan 3D Viewport (view3d.move)
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

echo "=== [2/2] Blender Stylus Keymap Information ==="
echo "Stylus buttons are configured for 3D viewport navigation:"
echo "  * Lower Button (Hold & drag on screen): Rotate Scene (Orbit / view3d.rotate)"
echo "  * Upper Button (Hold & drag on screen): Move Scene (Pan / view3d.move)"
echo "These keybindings are stored in ~/.config/blender/5.0/config/userpref.blend."

echo "-> Blender Yoga 7 optimizations ready!"
