#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Stylus, Touch & Screen Auto-Rotation Hardware Fix
# Yazar: Auxerov
# 
# Bu script donanım düzeyinde:
#  1. Kalemin yaklaşma/uzaklaşma (proximity) ve kfifo taşma (takılma) sorununu çözer.
#  2. Kalemin alt tuşunu evrensel Orta Tık (Middle Click) yapar (Chrome, Masaüstü, Blender vb.).
#  3. AMD Sensor Fusion Hub (AMD-SFH) ivmeölçerinin "Event data for report 1 was too short"
#     kernel hatasını gidererek GNOME ekran otomatik döndürmesini (auto-rotation) etkinleştirir.
#  4. Yeniden başlatma (boot) ve uykudan uyanma (sleep/resume) sonrasında kalıcıdır.
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "HATA: Lütfen bu scripti sudo ile çalıştırın: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BPF_DIR="/home/auxerov/Documents/Projects/Lenovo 2 in 1 Settings/resources"

PEN_BPF_SRC="${BPF_DIR}/lenovo_pen_fix.bpf.o"
PEN_BPF_DEST="/etc/udev-hid-bpf/lenovo_pen_fix.bpf.o"

SENSOR_BPF_SRC="${BPF_DIR}/lenovo_sensor_fix.bpf.o"
SENSOR_BPF_DEST="/etc/udev-hid-bpf/lenovo_sensor_fix.bpf.o"

echo "=== [1/4] Güncellenmiş HID-BPF Sürücüleri Kuruluyor ==="
mkdir -p /etc/udev-hid-bpf /etc/udev/rules.d /etc/systemd/system /etc/systemd/system-sleep

if [ ! -f "$PEN_BPF_SRC" ]; then
    echo "HATA: $PEN_BPF_SRC bulunamadı!"
    exit 1
fi

if [ ! -f "$SENSOR_BPF_SRC" ]; then
    echo "HATA: $SENSOR_BPF_SRC bulunamadı!"
    exit 1
fi

cp "$PEN_BPF_SRC" "$PEN_BPF_DEST"
chmod 644 "$PEN_BPF_DEST"
echo "✓ Kalem BPF sürücüsü /etc/udev-hid-bpf/ altına yerleştirildi."

cp "$SENSOR_BPF_SRC" "$SENSOR_BPF_DEST"
chmod 644 "$SENSOR_BPF_DEST"
echo "✓ Sensör/İvmeölçer BPF sürücüsü /etc/udev-hid-bpf/ altına yerleştirildi."

echo "=== [2/4] Donanıma ve Kernel'a Filtreler Uygulanıyor ==="
# Kalem filtresi (Wacom Digitizer)
for dev in /sys/bus/hid/devices/*056A:5363*; do
    if [ -d "$dev" ]; then
        echo "Kalem cihazına bağlanıyor: $dev"
        /usr/bin/udev-hid-bpf add --replace "$dev" "$PEN_BPF_DEST" || true
    fi
done

# Sensör / İvmeölçer filtresi (AMD-SFH)
for dev in /sys/bus/hid/devices/*1022:0001*; do
    if [ -d "$dev" ]; then
        echo "Sensör/İvmeölçer cihazına bağlanıyor: $dev"
        /usr/bin/udev-hid-bpf add --replace "$dev" "$SENSOR_BPF_DEST" || true
    fi
done

echo "=== [3/4] Kalıcılık Kuralları (Udev & Systemd Boot/Sleep) Yazılıyor ==="
# Kalem Udev kuralı
tee /etc/udev/rules.d/99-hid-bpf-lenovo_pen_fix.rules > /dev/null << 'EOF'
ACTION!="add|remove", GOTO="hid_bpf_end"
SUBSYSTEM!="hid", GOTO="hid_bpf_end"

# Lenovo Digital Pen 2 / Wacom HID 5363
ACTION=="add", ENV{MODALIAS}=="hid:b0018g0101v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf add --replace $sys$devpath /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o"
ACTION=="remove", ENV{MODALIAS}=="hid:b0018g0101v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf remove $sys$devpath"
ACTION=="add", ENV{MODALIAS}=="hid:b0018g*v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf add --replace $sys$devpath /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o"
ACTION=="remove", ENV{MODALIAS}=="hid:b0018g*v0000056Ap00005363", RUN{program}+="/usr/bin/udev-hid-bpf remove $sys$devpath"

LABEL="hid_bpf_end"
EOF

# Sensör Udev kuralı
tee /etc/udev/rules.d/99-hid-bpf-lenovo_sensor_fix.rules > /dev/null << 'EOF'
ACTION!="add|remove", GOTO="hid_bpf_end"
SUBSYSTEM!="hid", GOTO="hid_bpf_end"

# AMD SFH Accelerometer (Screen Auto-Rotation)
ACTION=="add", ENV{MODALIAS}=="hid:b0020g0003v00001022p00000001", RUN{program}+="/usr/bin/udev-hid-bpf add --replace $sys$devpath /etc/udev-hid-bpf/lenovo_sensor_fix.bpf.o"
ACTION=="remove", ENV{MODALIAS}=="hid:b0020g0003v00001022p00000001", RUN{program}+="/usr/bin/udev-hid-bpf remove $sys$devpath"
ACTION=="add", ENV{MODALIAS}=="hid:b0020g*v00001022p00000001", RUN{program}+="/usr/bin/udev-hid-bpf add --replace $sys$devpath /etc/udev-hid-bpf/lenovo_sensor_fix.bpf.o"
ACTION=="remove", ENV{MODALIAS}=="hid:b0020g*v00001022p00000001", RUN{program}+="/usr/bin/udev-hid-bpf remove $sys$devpath"

LABEL="hid_bpf_end"
EOF

# Systemd boot servisi
tee /etc/systemd/system/lenovo-pen-fix.service > /dev/null << 'EOF'
[Unit]
Description=Lenovo Yoga 7 2-in-1 Stylus & Sensor HID-BPF Hardware Fix
After=systemd-udevd.service suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
Wants=systemd-udevd.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c '\
for dev in /sys/bus/hid/devices/*056A:5363*; do [ -d "$dev" ] && [ -f /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o ] && /usr/bin/udev-hid-bpf add --replace "$dev" /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o; done; \
for dev in /sys/bus/hid/devices/*1022:0001*; do [ -d "$dev" ] && [ -f /etc/udev-hid-bpf/lenovo_sensor_fix.bpf.o ] && /usr/bin/udev-hid-bpf add --replace "$dev" /etc/udev-hid-bpf/lenovo_sensor_fix.bpf.o; done; \
systemctl restart iio-sensor-proxy.service || true\
'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF

# Uykudan uyanma (sleep/resume) kancası
tee /etc/systemd/system-sleep/lenovo-pen-fix.sh > /dev/null << 'EOF'
#!/bin/sh
case "$1" in
    post)
        /bin/systemctl restart lenovo-pen-fix.service
        ;;
esac
EOF
chmod +x /etc/systemd/system-sleep/lenovo-pen-fix.sh

systemctl daemon-reload
systemctl enable --now lenovo-pen-fix.service
udevadm control --reload
udevadm trigger --subsystem-match=hid || true
systemctl restart iio-sensor-proxy || true

echo "=== [4/4] GNOME Evrensel Kalem & Ekran Döndürme Yapılandırılıyor ==="
USER_NAME="${SUDO_USER:-$USER}"
USER_UID="$(id -u "$USER_NAME")"
USER_HOME=$(eval echo "~$USER_NAME")

# yoga-autorotate daemon'unu kullanıcı dizinine kur
mkdir -p "${USER_HOME}/.local/bin" "${USER_HOME}/.config/systemd/user"
if [ -f "${BPF_DIR}/yoga-autorotate" ]; then
    cp "${BPF_DIR}/yoga-autorotate" "${USER_HOME}/.local/bin/yoga-autorotate"
    chmod +x "${USER_HOME}/.local/bin/yoga-autorotate"
    chown "$USER_NAME:$USER_NAME" "${USER_HOME}/.local/bin/yoga-autorotate"
fi

# systemd user servisini oluştur
tee "${USER_HOME}/.config/systemd/user/yoga-autorotate.service" > /dev/null << 'SERVICE_EOF'
[Unit]
Description=Lenovo Yoga 7 Screen Auto-Rotation Daemon for GNOME Wayland
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 %h/.local/bin/yoga-autorotate
Restart=always
RestartSec=2
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical-session.target
SERVICE_EOF

chown -R "$USER_NAME:$USER_NAME" "${USER_HOME}/.config/systemd/user/yoga-autorotate.service"

# Kullanıcı oturumundaki dconf ayarlarını ve servisi aktifleştir
sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_UID}/bus" bash << 'USER_EOF'
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/secondary-button-action "'middle'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/eraser-button-action "'middle'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/eraser-button-mode "'button'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/button-action "'forward'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/pressure-curve "[0, 0, 100, 100]"
gsettings set org.gnome.settings-daemon.peripherals.touchscreen orientation-lock false

systemctl --user daemon-reload
systemctl --user enable --now yoga-autorotate.service || true
USER_EOF

echo ""
echo "=============================================================================="
echo "✓ BAŞARILI: Kalem ve Ekran Döndürme donanım düzeltmesi kalıcı olarak uygulandı!"
echo "  - Kalem: Proximity kfifo taşma (takılma) sorunu giderildi."
echo "  - Alt tuş: Evrensel Orta Tık (Chrome sekmeleri, Blender Orbit vb.)."
echo "  - Sensör: AMD-SFH ivmeölçer donanım hatası kernel seviyesinde giderildi."
echo "  - Ekran: GNOME Wayland otomatik ekran döndürme köprüsü (yoga-autorotate) aktif."
echo "  - Yeniden başlatma ve uyku modundan sonra da otomatik çalışır."
echo "=============================================================================="
