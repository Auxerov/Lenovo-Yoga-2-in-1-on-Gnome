#!/usr/bin/env bash
# ==============================================================================
# Lenovo Yoga 7 2-in-1 Stylus & Hardware Fix (Blender'dan Bağımsız Sistem Çözümü)
# Yazar: Auxerov
# 
# Bu script kalemin:
#  1. Ekrana yaklaşma/uzaklaşma (proximity) ve kfifo taşma (takılma) sorununu çözer.
#  2. Alt tuşu evrensel Orta Tık (Middle Click) yapar (Chrome, Masaüstü, Blender vb.).
#  3. Yeniden başlatma (boot) ve uykudan uyanma (sleep/resume) sonrasında kalıcıdır.
# ==============================================================================

set -e

if [ "$EUID" -ne 0 ]; then
    echo "HATA: Lütfen bu scripti sudo ile çalıştırın: sudo $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BPF_SRC="/home/auxerov/Documents/Projects/Lenovo 2 in 1 Settings/resources/lenovo_pen_fix.bpf.o"
BPF_DEST="/etc/udev-hid-bpf/lenovo_pen_fix.bpf.o"

echo "=== [1/4] Güncellenmiş HID-BPF Sürücüsü Kuruluyor ==="
mkdir -p /etc/udev-hid-bpf /etc/udev/rules.d /etc/systemd/system /etc/systemd/system-sleep

if [ ! -f "$BPF_SRC" ]; then
    echo "HATA: $BPF_SRC bulunamadı!"
    exit 1
fi

cp "$BPF_SRC" "$BPF_DEST"
chmod 644 "$BPF_DEST"
echo "✓ Sürücü ikili dosyası /etc/udev-hid-bpf/ altına yerleştirildi."

echo "=== [2/4] Donanıma ve Kernel'a Filtre Uygulanıyor ==="
for dev in /sys/bus/hid/devices/*056A:5363*; do
    if [ -d "$dev" ]; then
        echo "Donanım cihazına bağlanıyor: $dev"
        /usr/bin/udev-hid-bpf add --replace "$dev" "$BPF_DEST" || true
    fi
done

echo "=== [3/4] Kalıcılık Kuralları (Udev & Systemd Boot/Sleep) Yazılıyor ==="
# Udev kuralı (Cihaz takıldığında veya uyandığında otomatik yükler)
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

# Systemd boot servisi
tee /etc/systemd/system/lenovo-pen-fix.service > /dev/null << 'EOF'
[Unit]
Description=Lenovo Digital Pen 2 HID-BPF Driver Fix
After=systemd-udevd.service suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
Wants=systemd-udevd.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'for dev in /sys/bus/hid/devices/*056A:5363*; do [ -d "$dev" ] && /usr/bin/udev-hid-bpf add --replace "$dev" /etc/udev-hid-bpf/lenovo_pen_fix.bpf.o; done'
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

echo "=== [4/4] GNOME Evrensel Kalem Ayarları Yapılandırılıyor ==="
USER_NAME="${SUDO_USER:-$USER}"
USER_UID="$(id -u "$USER_NAME")"

# Kullanıcı oturumundaki dconf ayarlarını güncelle
sudo -u "$USER_NAME" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${USER_UID}/bus" bash << 'USER_EOF'
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/secondary-button-action "'middle'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/eraser-button-action "'middle'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/eraser-button-mode "'button'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/button-action "'forward'"
dconf write /org/gnome/desktop/peripherals/stylus/80e4ef9b/pressure-curve "[0, 0, 100, 100]"
USER_EOF

echo ""
echo "=============================================================================="
echo "✓ BAŞARILI: Kalem donanım düzeltmesi kalıcı olarak uygulandı!"
echo "  - Proximity kfifo taşma (takılma) sorunu giderildi."
echo "  - Alt tuş: Evrensel Orta Tık (Chrome sekmeleri, Blender Orbit vb.)."
echo "  - Üst tuş: İleri / Pan."
echo "  - Yeniden başlatma ve uyku modundan sonra da otomatik çalışır."
echo "=============================================================================="
