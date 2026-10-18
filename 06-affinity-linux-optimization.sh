#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 06-affinity-linux-optimization.sh
# 
# Functionality:
# - Affinity Suite (Photo, Designer, Publisher) Wine Crash & Input Lag Fixes:
#   1. New Document Preset Crash Resolution:
#      * Affinity attempts to call Windows Touch Interaction Context (ninput.dll)
#        when choosing a new document preset. The Wine stub threw NotImplementedException,
#        force-closing the application. Disabling ninput forces stable Wintab mode.
#   2. Input & Stylus Latency Reduction:
#      * DXVK buffer latency tuned: dxgi.maxFrameLatency = 1, dxgi.syncInterval = 0.
#   3. RAM Usage & Thrashing Fix:
#      * Affinity's default 24 GB allocation on a 13 GB RAM machine triggered Linux
#        disk swapping and stutters. Memory limit is safely capped to 8192 MB.
# ==============================================================================

set -e

WINEPREFIX_DIR="/home/auxerov/Software/.AffinityLinux"

echo "=== [1/3] ninput.dll Crash Fix ==="
if [ -d "$WINEPREFIX_DIR" ]; then
    SYS32="$WINEPREFIX_DIR/drive_c/windows/system32"
    if [ -f "$SYS32/ninput.dll" ]; then
        mv "$SYS32/ninput.dll" "$SYS32/ninput.dll.disabled"
        echo "ninput.dll successfully disabled."
    fi

    # Disable ninput in Wine registry DllOverrides
    USER_REG="$WINEPREFIX_DIR/user.reg"
    if [ -f "$USER_REG" ]; then
        if ! grep -q '"ninput"=""' "$USER_REG"; then
            sed -i '/\[Software\\\\Wine\\\\DllOverrides\]/a "ninput"=""\n"*ninput"=""' "$USER_REG"
            echo "Updated user.reg DllOverrides."
        fi
    fi
else
    echo "Info: Affinity Wineprefix ($WINEPREFIX_DIR) not found at default path, skipping."
fi

echo "=== [2/3] Tablet & Performance XML Preferences ==="
AFFINITY_APP_DIR="$WINEPREFIX_DIR/drive_c/users/auxerov/AppData/Roaming/Affinity"
if [ -d "$AFFINITY_APP_DIR" ]; then
    find "$AFFINITY_APP_DIR" -type f -name "ToolsPreferences.xml" | while read -r f; do
        sed -i 's/<TabletPolicy>[0-9]*<\/TabletPolicy>/<TabletPolicy>2<\/TabletPolicy>/g' "$f"
        echo "Tablet policy set to Wintab (2): $f"
    done

    find "$AFFINITY_APP_DIR" -type f -name "PerformancePreferences.xml" | while read -r f; do
        sed -i 's/<RAMUsageLimit>[0-9]*<\/RAMUsageLimit>/<RAMUsageLimit>8192<\/RAMUsageLimit>/g' "$f"
        sed -i 's/<UndoLimit>[0-9]*<\/UndoLimit>/<UndoLimit>256<\/UndoLimit>/g' "$f"
        sed -i 's/<ViewQuality>[0-9]*<\/ViewQuality>/<ViewQuality>1<\/ViewQuality>/g' "$f"
        sed -i 's/<RetinaPassIndex>[0-9]*<\/RetinaPassIndex>/<RetinaPassIndex>1<\/RetinaPassIndex>/g' "$f"
        echo "Optimized performance preferences: $f"
    done
fi

echo "=== [3/3] DXVK Low-Latency Desktop Launcher Update ==="
DESKTOP_ENTRY="/home/auxerov/.local/share/applications/Affinity.desktop"
if [ -f "$DESKTOP_ENTRY" ]; then
    sed -i 's/env DXVK_CONFIG="[^"]*"/env DXVK_CONFIG="dxgi.maxFrameLatency = 1; dxgi.syncInterval = 0; d3d9.deferSurfaceCreation = True; d3d9.shaderModel = 1"/g' "$DESKTOP_ENTRY"
    if [ -f "/home/auxerov/Desktop/Affinity.desktop" ]; then
        cp "$DESKTOP_ENTRY" "/home/auxerov/Desktop/Affinity.desktop"
    fi
    echo "Affinity.desktop launcher updated with DXVK low-latency parameters."
fi

echo "-> Affinity Linux optimizations successfully applied!"
