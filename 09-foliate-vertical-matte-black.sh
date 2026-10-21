#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 09-foliate-vertical-matte-black.sh
# 
# Functionality:
# - Configures Foliate E-Book Reader for comfortable, continuous reading:
#   1. Continuous Vertical Reading Mode (Scrolled Layout):
#      * Enables uninterrupted vertical scrolling (webtoon / document style)
#        rather than artificial two-page or paginated spreads.
#   2. True Matte Black Theme:
#      * Replaces harsh pitch-black (#000000) or glaring white backgrounds with
#        a soothing matte dark background (#121212) and soft light gray text (#e0e0e0)
#        to eliminate halation, glare, and eye strain in low-light environments.
#   3. Continuous Auto-Section Navigation:
#      * Eliminates section boundaries when scrolling. When scrolling down to the
#        end of a chapter/section, continuing to scroll or swiping up automatically
#        advances to the next chapter at the top (anchor 0).
#      * Scrolling up at the beginning of a chapter smoothly navigates back to the
#        previous chapter at the bottom (anchor 1).
#      * Works seamlessly with touchpad, mouse wheel, and touchscreen gestures,
#        incorporating momentum cooldown to prevent accidental chapter skipping.
# ==============================================================================

set -e

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="${SCRIPT_DIR}/resources/foliate"
FOLIATE_CONFIG_DIR="${HOME}/.config/com.github.johnfactotum.Foliate"
THEMES_DIR="${FOLIATE_CONFIG_DIR}/themes"
OVERRIDES_DIR="${FOLIATE_CONFIG_DIR}/overrides/foliate-js"
LOCAL_BIN_DIR="${HOME}/.local/bin"
LOCAL_APPS_DIR="${HOME}/.local/share/applications"

echo -e "${BLUE}=== [1/5] Checking Foliate Installation ===${NC}"
if ! command -v foliate &>/dev/null && [ ! -f "/usr/bin/foliate" ]; then
    echo -e "${YELLOW}[!] Foliate is not currently installed.${NC}"
    echo -e "${YELLOW}[!] Installing Foliate via DNF...${NC}"
    sudo dnf install -y foliate
fi
echo -e "${GREEN}[✓] Foliate binary detected.${NC}"

echo -e "${BLUE}=== [2/5] Configuring GSettings for Foliate Viewer ===${NC}"
# Enable continuous scrolled vertical reading mode
gsettings set com.github.johnfactotum.Foliate.viewer.view scrolled true
# Activate Matte Black theme by default
gsettings set com.github.johnfactotum.Foliate.viewer.view theme 'matte-black.json'
# Enable smooth animation transitions
gsettings set com.github.johnfactotum.Foliate.viewer.view animated true
echo -e "${GREEN}[✓] GSettings updated (scrolled=true, theme='matte-black.json', animated=true).${NC}"

echo -e "${BLUE}=== [3/5] Installing Matte Black Theme and Custom Stylesheet ===${NC}"
mkdir -p "${THEMES_DIR}"

if [ -f "${RESOURCES_DIR}/matte-black.json" ]; then
    cp "${RESOURCES_DIR}/matte-black.json" "${THEMES_DIR}/matte-black.json"
else
    cat << 'EOF' > "${THEMES_DIR}/matte-black.json"
{
    "label": "Mat Siyah (Matte Black)",
    "light": {
        "fg": "#e0e0e0",
        "bg": "#121212",
        "link": "#89b4fa"
    },
    "dark": {
        "fg": "#e0e0e0",
        "bg": "#121212",
        "link": "#89b4fa"
    }
}
EOF
fi

if [ -f "${RESOURCES_DIR}/user-stylesheet.css" ]; then
    cp "${RESOURCES_DIR}/user-stylesheet.css" "${FOLIATE_CONFIG_DIR}/user-stylesheet.css"
else
    cat << 'EOF' > "${FOLIATE_CONFIG_DIR}/user-stylesheet.css"
/* Foliate Mat Siyah & Yumuşak Beyaz Okuma Stili (Matte Black Theme) */
html, body {
    background-color: #121212 !important;
    color: #e0e0e0 !important;
}

body * {
    background-color: transparent !important;
    color: #e0e0e0 !important;
}

a, a:visited, a:hover {
    color: #89b4fa !important;
}

img, svg {
    filter: none !important;
}
EOF
fi
echo -e "${GREEN}[✓] Matte black theme and CSS stylesheet installed.${NC}"

echo -e "${BLUE}=== [4/5] Deploying Continuous Paginator Auto-Advance Patch ===${NC}"
mkdir -p "${OVERRIDES_DIR}"

if [ -f "${RESOURCES_DIR}/paginator.js" ]; then
    cp "${RESOURCES_DIR}/paginator.js" "${OVERRIDES_DIR}/paginator.js"
    echo -e "${GREEN}[✓] Paginator override deployed from resources.${NC}"
else
    echo -e "${RED}[!] Error: ${RESOURCES_DIR}/paginator.js not found!${NC}"
    exit 1
fi

echo -e "${BLUE}=== [5/5] Configuring Local Launcher Wrapper & Desktop Entry ===${NC}"
mkdir -p "${LOCAL_BIN_DIR}" "${LOCAL_APPS_DIR}"

if [ -f "${RESOURCES_DIR}/foliate.wrapper" ]; then
    cp "${RESOURCES_DIR}/foliate.wrapper" "${LOCAL_BIN_DIR}/foliate"
    chmod +x "${LOCAL_BIN_DIR}/foliate"
else
    cat << 'EOF' > "${LOCAL_BIN_DIR}/foliate"
#!/usr/bin/gjs-console -m
// Foliate launcher with user override support
const MESON = true

import Gtk from 'gi://Gtk?version=4.0'
import Gio from 'gi://Gio?version=2.0'
import GLib from 'gi://GLib?version=2.0'
import 'gi://Adw?version=1'
import 'gi://WebKit?version=6.0'
import { programInvocationName, programArgs, exit }  from 'system'
import { bindtextdomain, textdomain, gettext as _ } from 'gettext'
import { setConsoleLogDomain } from 'console'

globalThis.pkg = {
    name: 'com.github.johnfactotum.Foliate',
    version: '3.3.0',
    MESON,
}
pkg.userAgent = `Foliate/${pkg.version}`

GLib.set_prgname(pkg.name)
setConsoleLogDomain(pkg.name)
Gtk.Window.set_default_icon_name(pkg.name)
bindtextdomain(pkg.name, GLib.build_filenamev(['/usr/share', 'locale']))
textdomain(pkg.name)

pkg.localeName = _('Foliate')
GLib.set_application_name(pkg.localeName)

pkg.datadir = GLib.build_filenamev([GLib.get_user_data_dir(), pkg.name])
pkg.datapath = path => GLib.build_filenamev([pkg.datadir, path])
pkg.datafile = path => Gio.File.new_for_path(pkg.datapath(path))

pkg.configdir = GLib.build_filenamev([GLib.get_user_config_dir(), pkg.name])
pkg.configpath = path => GLib.build_filenamev([pkg.configdir, path])

pkg.cachedir = GLib.build_filenamev([GLib.get_user_cache_dir(), pkg.name])
pkg.cachepath = path => GLib.build_filenamev([pkg.cachedir, path])

// Register base GResource binary from system installation
Gio.Resource
    .load(GLib.build_filenamev(['/usr/share', pkg.name, `${pkg.name}.gresource`]))
    ._register()

const moduledir = '/' + pkg.name.replaceAll('.', '/')
const overrideDir = GLib.build_filenamev([pkg.configdir, 'overrides'])

pkg.modulepath = path => GLib.build_filenamev([moduledir, path])
pkg.moduleuri = path => {
    const cleanPath = path.startsWith('/') ? path.slice(1) : path
    const overrideFile = GLib.build_filenamev([overrideDir, cleanPath])
    if (GLib.file_test(overrideFile, GLib.FileTest.EXISTS)) {
        return GLib.filename_to_uri(overrideFile, null)
    }
    return `resource://${pkg.modulepath(path)}`
}
pkg.useResource = MESON

const { Application } = await import(pkg.moduleuri('app.js'))
exit(await new Application().runAsync([programInvocationName, ...programArgs]))
EOF
    chmod +x "${LOCAL_BIN_DIR}/foliate"
fi

# Ensure desktop entry launches the user wrapper
if [ -f "/usr/share/applications/com.github.johnfactotum.Foliate.desktop" ]; then
    cp "/usr/share/applications/com.github.johnfactotum.Foliate.desktop" "${LOCAL_APPS_DIR}/com.github.johnfactotum.Foliate.desktop"
    sed -i "s|^Exec=foliate %U|Exec=${LOCAL_BIN_DIR}/foliate %U|" "${LOCAL_APPS_DIR}/com.github.johnfactotum.Foliate.desktop"
    update-desktop-database "${LOCAL_APPS_DIR}" 2>/dev/null || true
fi

echo -e "${GREEN}[✓] Foliate wrapper launcher and desktop shortcut configured successfully.${NC}"
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  Foliate Vertical Mode & Auto-Advance Setup Completed Successfully!          ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
