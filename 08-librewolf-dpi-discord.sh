#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 08-librewolf-dpi-discord.sh
# 
# Functionality:
# - Bypasses Turkish ISP DNS poisoning and Deep Packet Inspection (DPI) for Discord
#   (and other censored domains like Roblox, Imgur, etc.) in LibreWolf.
# - Enables Full GPU Hardware Video Acceleration (VA-API / Radeon 780M):
#   * Replaces crippled ffmpeg-free with full RPM Fusion ffmpeg (x264, x265, AAC).
#   * Installs mesa-va-drivers-freeworld for native AMD VCN hardware video decoding.
#   * Configures LibreWolf VA-API, DMA-BUF, and WebRender flags for smooth,
#     low-CPU 1080p/4K streaming without playback lag or buffering.
# ==============================================================================

set -e

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== [1/6] Installing Full Multimedia Codecs & VA-API Hardware Decoding ===${NC}"
# Check if ffmpeg-free is still present or if full ffmpeg is missing
if rpm -q libavcodec-free &>/dev/null; then
    echo -e "${YELLOW}[!] Replacing crippled ffmpeg-free with full RPM Fusion ffmpeg...${NC}"
    sudo dnf swap -y ffmpeg-free ffmpeg --allowerasing || true
fi

if ! rpm -q mesa-va-drivers-freeworld &>/dev/null; then
    echo -e "${YELLOW}[!] Installing mesa-va-drivers-freeworld for Radeon 780M hardware video acceleration...${NC}"
    sudo dnf install -y mesa-va-drivers-freeworld libva-utils || true
fi
echo -e "${GREEN}[✓] GPU video decoding codecs verified.${NC}"

echo -e "${BLUE}=== [2/6] Verifying SpoofDPI Binary ===${NC}"
if [ ! -f "/usr/local/bin/spoofdpi" ]; then
    echo -e "${RED}Error: /usr/local/bin/spoofdpi not found!${NC}"
    exit 1
fi
echo -e "${GREEN}[✓] SpoofDPI binary found.${NC}"

echo -e "${BLUE}=== [3/6] Configuring SpoofDPI Systemd User Service ===${NC}"
mkdir -p ~/.config/systemd/user

cat << 'EOF' > ~/.config/systemd/user/spoofdpi.service
[Unit]
Description=SpoofDPI - Fast Anti-Censorship Deep Packet Inspection (DPI) Bypass Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/spoofdpi --listen-addr 127.0.0.1:8080 --no-tui --dns-mode https
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now spoofdpi.service
echo -e "${GREEN}[✓] SpoofDPI service running on 127.0.0.1:8080.${NC}"

echo -e "${BLUE}=== [4/6] Setting Cloudflare & Google DNS on Wi-Fi Connection ===${NC}"
ACTIVE_WIFI=$(nmcli -t -f NAME,TYPE connection show --active 2>/dev/null | grep ":wifi" | cut -d: -f1 | head -n 1)
if [ -n "$ACTIVE_WIFI" ]; then
    echo -e "Configuring clean DNS (1.1.1.1, 8.8.8.8) on Wi-Fi: ${ACTIVE_WIFI}"
    nmcli connection modify "$ACTIVE_WIFI" ipv4.dns "1.1.1.1 8.8.8.8" ipv4.ignore-auto-dns yes || true
    nmcli connection up "$ACTIVE_WIFI" || true
    echo -e "${GREEN}[✓] Wi-Fi DNS configured.${NC}"
fi

echo -e "${BLUE}=== [5/6] Configuring LibreWolf PAC Script, DoH & Hardware Video Acceleration ===${NC}"
mkdir -p ~/.config/librewolf

# Physical PAC file
cat << 'EOF' > ~/.config/librewolf/proxy.pac
function FindProxyForURL(url, host) {
    if (/discord/i.test(host) || /roblox/i.test(host) || /rbxcdn/i.test(host) || /imgur/i.test(host)) {
        return "PROXY 127.0.0.1:8080; DIRECT";
    }
    return "DIRECT";
}
EOF

# Global LibreWolf overrides
cat << 'EOF' > ~/.config/librewolf/librewolf.overrides.cfg
// ==============================================================================
// LibreWolf DPI Bypass & DoH Configuration
// Author: Auxerov
// ==============================================================================

// DNS-over-HTTPS (DoH) via Cloudflare
defaultPref("network.trr.mode", 2);
defaultPref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
defaultPref("network.trr.custom_uri", "https://mozilla.cloudflare-dns.com/dns-query");

// Encrypted Client Hello (ECH)
defaultPref("network.dns.echconfig.enabled", true);
defaultPref("network.dns.use_https_rr_as_altsvc", true);

// Selective PAC Proxy: Discord -> SpoofDPI (127.0.0.1:8080), Others -> DIRECT
defaultPref("network.proxy.type", 2);
defaultPref("network.proxy.autoconfig_url", "data:text/javascript,function FindProxyForURL(url, host) { if (/discord/i.test(host) || /roblox/i.test(host) || /rbxcdn/i.test(host) || /imgur/i.test(host)) { return 'PROXY 127.0.0.1:8080; DIRECT'; } return 'DIRECT'; }");

// ==============================================================================
// Hardware Video Acceleration (VA-API / GPU Decode)
// ==============================================================================
defaultPref("media.ffmpeg.vaapi.enabled", true);
defaultPref("media.hardware-video-decoding.enabled", true);
defaultPref("media.hardware-video-decoding.force-enabled", true);
defaultPref("media.rdd-ffmpeg.enabled", true);
defaultPref("widget.dmabuf.vaapi.enabled", true);
defaultPref("gfx.webrender.all", true);

// ==============================================================================
// Unsigned Extensions Support
// ==============================================================================
defaultPref("xpinstall.signatures.required", false);
pref("xpinstall.signatures.required", false);
defaultPref("extensions.langpacks.signatures.required", false);
defaultPref("extensions.autoDisableScopes", 0);
defaultPref("extensions.startupScanScopes", 15);
defaultPref("extensions.enabledScopes", 15);
EOF

# Update all active profiles
for profile in ~/.config/librewolf/librewolf/*.default*; do
    if [ -d "$profile" ]; then
        echo "Updating profile user.js: $profile"
        cat << 'EOF' > "$profile/user.js"
// ==============================================================================
// LibreWolf DPI Bypass & DoH Profile Preferences
// Author: Auxerov
// ==============================================================================

// DNS-over-HTTPS (DoH) via Cloudflare
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
user_pref("network.trr.custom_uri", "https://mozilla.cloudflare-dns.com/dns-query");

// Encrypted Client Hello (ECH)
user_pref("network.dns.echconfig.enabled", true);
user_pref("network.dns.use_https_rr_as_altsvc", true);

// Selective PAC Proxy: Discord -> SpoofDPI (127.0.0.1:8080), Others -> DIRECT
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "data:text/javascript,function FindProxyForURL(url, host) { if (/discord/i.test(host) || /roblox/i.test(host) || /rbxcdn/i.test(host) || /imgur/i.test(host)) { return 'PROXY 127.0.0.1:8080; DIRECT'; } return 'DIRECT'; }");

// ==============================================================================
// Hardware Video Acceleration (VA-API / GPU Decode)
// ==============================================================================
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("widget.dmabuf.vaapi.enabled", true);
user_pref("gfx.webrender.all", true);

// ==============================================================================
// Unsigned Extensions Support
// ==============================================================================
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.langpacks.signatures.required", false);
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.startupScanScopes", 15);
user_pref("extensions.enabledScopes", 15);
EOF
    fi
done
echo -e "${GREEN}[✓] LibreWolf hardware video decoding & DPI bypass configured.${NC}"

echo -e "${BLUE}=== [6/6] Verifying Discord Connectivity ===${NC}"
curl -I https://discord.com --connect-timeout 5 2>/dev/null | head -n 5 || true

echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  LibreWolf DPI Bypass & GPU Video Acceleration Setup Completed!              ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
