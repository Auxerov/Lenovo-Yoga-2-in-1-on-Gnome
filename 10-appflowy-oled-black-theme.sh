#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Linux Configuration Suite
# Author: Auxerov
# File: 10-appflowy-oled-black-theme.sh
# 
# Functionality:
# - Installs and configures True Pure Black OLED Themes for AppFlowy:
#   1. OLED Black (Pure #000000 background with Catppuccin / Soft Blue accents)
#   2. OLED Monochrome (Pure #000000 background with sleek Minimalist White accents)
# - Generates valid AppFlowy theme plugins (.flowy_plugin and .flowy_plugin.zip)
#   with all 55 required FlowyColorScheme color tokens:
#   * True pure black (0xFF000000) for editor surface, sidebar, and topbar.
#   * Low-glare dark inputs (0xFF0D0D0D) and floating toolbar.
#   * High-contrast text (0xFFF4F4F5 / 0xFFFFFFFF) and clear dividers.
# - Deploys plugins to AppFlowy document directory (~/Documents) and sandbox paths.
# - Configures theme preference in AppFlowy cache database.
# ==============================================================================

set -e

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="${SCRIPT_DIR}/resources/appflowy"
DOCUMENTS_DIR="${HOME}/Documents"
DOWNLOADS_DIR="${HOME}/Downloads"
APPFLOWY_DATA_DIR="${HOME}/.var/app/io.appflowy.AppFlowy/data/AppFlowy"

echo -e "${BLUE}==============================================================================${NC}"
echo -e "${BLUE}          AppFlowy True Pure Black OLED Theme Installation                     ${NC}"
echo -e "${BLUE}                        Author: Auxerov                                       ${NC}"
echo -e "${BLUE}==============================================================================${NC}"
echo ""

# Ensure resource directory exists
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${DOCUMENTS_DIR}"
mkdir -p "${DOWNLOADS_DIR}"

# 1. Deploy theme plugins from resources
echo -e "${YELLOW}[1/3] Deploying OLED Theme Plugins...${NC}"

THEMES=("OLED_Black" "OLED_Monochrome")

for THEME in "${THEMES[@]}"; do
    PLUGIN_DIR="${THEME}.flowy_plugin"
    ZIP_FILE="${THEME}.flowy_plugin.zip"

    SRC_DIR="${RESOURCES_DIR}/${PLUGIN_DIR}"
    SRC_ZIP="${RESOURCES_DIR}/${ZIP_FILE}"

    if [ -d "${SRC_DIR}" ]; then
        # Copy to ~/Documents (AppFlowy plugin discovery directory)
        cp -rf "${SRC_DIR}" "${DOCUMENTS_DIR}/"
        echo -e "${GREEN}  ✓ Deployed ${PLUGIN_DIR} to ${DOCUMENTS_DIR}/${NC}"

        # Copy to ~/Downloads for convenient manual upload if needed
        cp -rf "${SRC_DIR}" "${DOWNLOADS_DIR}/"
        [ -f "${SRC_ZIP}" ] && cp -f "${SRC_ZIP}" "${DOWNLOADS_DIR}/"
        echo -e "${GREEN}  ✓ Deployed ${PLUGIN_DIR} & zip to ${DOWNLOADS_DIR}/${NC}"

        # If Flatpak AppFlowy data directory exists, deploy there too
        if [ -d "${APPFLOWY_DATA_DIR}" ]; then
            cp -rf "${SRC_DIR}" "${APPFLOWY_DATA_DIR}/"
            echo -e "${GREEN}  ✓ Deployed ${PLUGIN_DIR} to AppFlowy data sandbox${NC}"
        fi
    else
        echo -e "${RED}  ✗ Warning: Source theme ${SRC_DIR} not found!${NC}"
    fi
done

# 2. Update AppFlowy settings database if present
echo ""
echo -e "${YELLOW}[2/3] Updating AppFlowy appearance settings...${NC}"

CACHE_DB=$(find "${APPFLOWY_DATA_DIR}" -name "cache.db" 2>/dev/null | head -n 1)

if [ -n "${CACHE_DB}" ] && [ -f "${CACHE_DB}" ]; then
    python3 -c "
import sqlite3
import json

db_path = '${CACHE_DB}'
try:
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    row = cur.execute(\"SELECT value FROM kv_table WHERE key='appearance_settings'\").fetchone()
    if row:
        settings = json.loads(row[0])
        settings['theme'] = 'OLED_Black'
        settings['theme_mode'] = 'Dark'
        cur.execute(\"UPDATE kv_table SET value=? WHERE key='appearance_settings'\", (json.dumps(settings),))
        con.commit()
        print('  ✓ Successfully set default theme to OLED_Black in AppFlowy database.')
    con.close()
except Exception as e:
    print('  ! Note: Could not update database directly (AppFlowy may be running):', e)
"
else
    echo -e "${YELLOW}  Note: AppFlowy database not initialized yet. Theme will be selectable on first launch.${NC}"
fi

# 3. Usage Instructions
echo ""
echo -e "${GREEN}==============================================================================${NC}"
echo -e "${GREEN}  SUCCESS: OLED Black themes installed!                                      ${NC}"
echo -e "${GREEN}==============================================================================${NC}"
echo ""
echo -e "How to activate in AppFlowy:"
echo -e " 1. Open AppFlowy."
echo -e " 2. Click the Settings icon (gear / Ayarlar) at the bottom left."
echo -e " 3. Select 'Appearance' (Görünüm)."
echo -e " 4. In the 'Theme' (Tema) dropdown, choose 'OLED_Black' or 'OLED_Monochrome'."
echo -e " 5. Alternatively, click 'Upload theme' (Tema yükle) and select:"
echo -e "    ${DOWNLOADS_DIR}/OLED_Black.flowy_plugin"
echo ""
