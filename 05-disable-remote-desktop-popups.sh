#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 05-disable-remote-desktop-popups.sh
# 
# Functionality:
# - Suppress GNOME Shell '+ 2 Remote Desktop' Nag Dialogs & Top Panel Indicator:
#   * When apps like Steam or XWayland clients request input emulation (XTEST / libei),
#     Mutter spawns RemoteDesktop portal sessions.
#   * If unhandled or hanging, GNOME displays persistent '+ 2 Remote Desktop' warnings.
#   * This script disables the RemoteDesktop portal interface via portals.conf, masks
#     gnome-remote-desktop.service, and clears stuck portal sessions.
#   * NOTE: Standard screen recording, screenshots, and OBS/Discord screen sharing
#     remain fully functional and unaffected!
# ==============================================================================

set -e

echo "=== [1/3] XDG Desktop Portal Configuration ==="
mkdir -p ~/.config/xdg-desktop-portal

# Disable RemoteDesktop portal for both GNOME desktop and general fallback
tee ~/.config/xdg-desktop-portal/gnome-portals.conf > /dev/null << 'EOF'
[preferred]
default=gnome;gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring;
org.freedesktop.impl.portal.RemoteDesktop=none;
EOF

cp ~/.config/xdg-desktop-portal/gnome-portals.conf ~/.config/xdg-desktop-portal/portals.conf

echo "=== [2/3] Masking GNOME Remote Desktop User Service ==="
systemctl --user mask gnome-remote-desktop.service 2>/dev/null || true

echo "=== [3/3] Restarting Portal Services & Clearing Hanging Sessions ==="
systemctl --user restart xdg-desktop-portal-gnome 2>/dev/null || true
systemctl --user restart xdg-desktop-portal 2>/dev/null || true

echo "-> Remote Desktop portal popups and top bar indicator successfully disabled!"
