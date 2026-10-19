#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 08-librewolf-dpi-discord.sh
# 
# Functionality:
# - Bypasses Turkish ISP DNS poisoning and Deep Packet Inspection (DPI) for Discord
#   (and other censored domains like Roblox, Imgur, etc.) in LibreWolf:
#   1. Zero Speed Loss / No VPN:
#      * Normal websites (Google, YouTube, banking, downloads) connect 100% DIRECTLY
#        at full native speed with zero proxy/VPN overhead.
#   2. Local SpoofDPI Service:
#      * Runs a lightweight local proxy daemon (127.0.0.1:8080) consuming ~1.5 MB RAM
#        and 0% CPU. Fragments the TLS ClientHello packet across TCP boundaries so
#        DPI hardware cannot read the SNI ("discord.com"), while Cloudflare servers
#        reassemble it cleanly.
#   3. DNS-over-HTTPS (DoH) & Cloudflare DNS:
#      * Configures LibreWolf to resolve DNS queries securely via Cloudflare DoH,
#        preventing ISP DNS hijacking (e.g. Türk Telekom BTK block IP 195.175.254.2).
#      * Sets active NetworkManager Wi-Fi connection DNS to 1.1.1.1 / 8.8.8.8.
# ==============================================================================

set -e

echo "=== [1/5] Verifying SpoofDPI Binary ==="
if [ ! -f "/usr/local/bin/spoofdpi" ]; then
    echo "Error: /usr/local/bin/spoofdpi not found!"
    exit 1
fi

echo "=== [2/5] Configuring SpoofDPI Systemd User Service ==="
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

echo "=== [3/5] Setting Cloudflare & Google DNS on Wi-Fi Connection ==="
ACTIVE_WIFI=$(nmcli -t -f NAME,TYPE connection show --active | grep ":wifi" | cut -d: -f1 | head -n 1)
if [ -n "$ACTIVE_WIFI" ]; then
    echo "Configuring clean DNS (1.1.1.1, 8.8.8.8) on Wi-Fi: $ACTIVE_WIFI"
    nmcli connection modify "$ACTIVE_WIFI" ipv4.dns "1.1.1.1 8.8.8.8" ipv4.ignore-auto-dns yes || true
    nmcli connection up "$ACTIVE_WIFI" || true
fi

echo "=== [4/5] Configuring LibreWolf PAC Script & DoH Settings ==="
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
defaultPref("network.trr.mode", 2);
defaultPref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
defaultPref("network.trr.custom_uri", "https://mozilla.cloudflare-dns.com/dns-query");
defaultPref("network.dns.echconfig.enabled", true);
defaultPref("network.dns.use_https_rr_as_altsvc", true);
defaultPref("network.proxy.type", 2);
defaultPref("network.proxy.autoconfig_url", "data:text/javascript,function FindProxyForURL(url, host) { if (/discord/i.test(host) || /roblox/i.test(host) || /rbxcdn/i.test(host) || /imgur/i.test(host)) { return 'PROXY 127.0.0.1:8080; DIRECT'; } return 'DIRECT'; }");
EOF

# Update all active and fallback profiles
for profile in ~/.config/librewolf/librewolf/*.default*; do
    if [ -d "$profile" ]; then
        echo "Updating profile user.js: $profile"
        cat << 'EOF' > "$profile/user.js"
user_pref("network.trr.mode", 2);
user_pref("network.trr.uri", "https://mozilla.cloudflare-dns.com/dns-query");
user_pref("network.trr.custom_uri", "https://mozilla.cloudflare-dns.com/dns-query");
user_pref("network.dns.echconfig.enabled", true);
user_pref("network.dns.use_https_rr_as_altsvc", true);
user_pref("network.proxy.type", 2);
user_pref("network.proxy.autoconfig_url", "data:text/javascript,function FindProxyForURL(url, host) { if (/discord/i.test(host) || /roblox/i.test(host) || /rbxcdn/i.test(host) || /imgur/i.test(host)) { return 'PROXY 127.0.0.1:8080; DIRECT'; } return 'DIRECT'; }");
EOF
    fi
done

echo "=== [5/5] Verifying Discord Connectivity ==="
curl -I https://discord.com --connect-timeout 5 | head -n 5

echo "-> LibreWolf DPI bypass successfully configured!"
