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
#   4. Shelf System & Collection Management:
#      * Adds a full shelf management system to organize books into custom
#        collections (e.g. Favorites, Reading, Completed, and user-defined shelves).
#      * Allows filtering library books by selecting any shelf in the sidebar.
#   5. Right-Click "Mark as Read" (100% Progress):
#      * Enables right-clicking any book card or row to mark it as Read (instantly
#        setting progress to 100% and moving to Completed shelf) or Mark as Unread (0%).
#      * Provides an "Add to Shelf…" action to easily toggle shelf memberships.
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
OVERRIDES_DIR="${FOLIATE_CONFIG_DIR}/overrides"
LOCAL_BIN_DIR="${HOME}/.local/bin"
LOCAL_APPS_DIR="${HOME}/.local/share/applications"

echo -e "${BLUE}=== [1/6] Checking Foliate Installation ===${NC}"
if ! command -v foliate &>/dev/null && [ ! -f "/usr/bin/foliate" ]; then
    echo -e "${YELLOW}[!] Foliate is not currently installed.${NC}"
    echo -e "${YELLOW}[!] Installing Foliate via DNF...${NC}"
    sudo dnf install -y foliate
fi
echo -e "${GREEN}[✓] Foliate binary detected.${NC}"

echo -e "${BLUE}=== [2/6] Configuring GSettings for Foliate Viewer ===${NC}"
# Enable continuous scrolled vertical reading mode
gsettings set com.github.johnfactotum.Foliate.viewer.view scrolled true
# Activate Matte Black theme by default
gsettings set com.github.johnfactotum.Foliate.viewer.view theme 'matte-black.json'
# Enable smooth animation transitions
gsettings set com.github.johnfactotum.Foliate.viewer.view animated true
echo -e "${GREEN}[✓] GSettings updated (scrolled=true, theme='matte-black.json', animated=true).${NC}"

echo -e "${BLUE}=== [3/6] Installing Matte Black Theme and Stylesheet ===${NC}"
mkdir -p "${THEMES_DIR}"

if [ -f "${RESOURCES_DIR}/matte-black.json" ]; then
    cp "${RESOURCES_DIR}/matte-black.json" "${THEMES_DIR}/matte-black.json"
else
    cat << 'EOF' > "${THEMES_DIR}/matte-black.json"
{
    "label": "Matte Black",
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
/* Foliate Matte Black & Soft White Reading Style */
html, body {
    background: #121212 !important;
    background-color: #121212 !important;
    color: #e0e0e0 !important;
}

body * {
    color: #e0e0e0 !important;
}

p, div, span, article, section, main, h1, h2, h3, h4, h5, h6, li, blockquote {
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

echo -e "${BLUE}=== [4/6] Deploying Continuous Paginator & Reader Overrides ===${NC}"
mkdir -p "${OVERRIDES_DIR}/foliate-js" "${OVERRIDES_DIR}/reader" "${OVERRIDES_DIR}/ui"

if [ -f "${RESOURCES_DIR}/paginator.js" ]; then
    cp "${RESOURCES_DIR}/paginator.js" "${OVERRIDES_DIR}/foliate-js/paginator.js"
    echo -e "${GREEN}[✓] Paginator override deployed.${NC}"
fi

if [ -f "${RESOURCES_DIR}/reader.js" ]; then
    cp "${RESOURCES_DIR}/reader.js" "${OVERRIDES_DIR}/reader/reader.js"
    echo -e "${GREEN}[✓] Reader background override deployed.${NC}"
fi

echo -e "${BLUE}=== [5/6] Deploying Library Shelf System & Context Menu Overrides ===${NC}"
if [ -f "${RESOURCES_DIR}/library.js" ]; then
    cp "${RESOURCES_DIR}/library.js" "${OVERRIDES_DIR}/library.js"
    echo -e "${GREEN}[✓] Library Shelf & Mark as Read controller deployed.${NC}"
fi

if [ -f "${RESOURCES_DIR}/book-item.ui" ]; then
    cp "${RESOURCES_DIR}/book-item.ui" "${OVERRIDES_DIR}/ui/book-item.ui"
    echo -e "${GREEN}[✓] Book item UI template deployed.${NC}"
fi

if [ -f "${RESOURCES_DIR}/book-row.ui" ]; then
    cp "${RESOURCES_DIR}/book-row.ui" "${OVERRIDES_DIR}/ui/book-row.ui"
    echo -e "${GREEN}[✓] Book row UI template deployed.${NC}"
fi

echo -e "${BLUE}=== [6/6] Configuring Local Launcher Wrapper & Desktop Entry ===${NC}"
mkdir -p "${LOCAL_BIN_DIR}" "${LOCAL_APPS_DIR}"

if [ -f "${RESOURCES_DIR}/foliate.wrapper" ]; then
    cp "${RESOURCES_DIR}/foliate.wrapper" "${LOCAL_BIN_DIR}/foliate"
    chmod +x "${LOCAL_BIN_DIR}/foliate"
else
    cat << 'EOF' > "${LOCAL_BIN_DIR}/foliate"
#!/usr/bin/env bash
# Foliate launcher with native GLib GResource overlays for user customization
export G_RESOURCE_OVERLAYS="/com/github/johnfactotum/Foliate=${HOME}/.config/com.github.johnfactotum.Foliate/overrides"
exec /usr/bin/foliate "$@"
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
echo -e "${GREEN}  Foliate Vertical Mode, Matte Black & Shelf Setup Completed Successfully!    ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
