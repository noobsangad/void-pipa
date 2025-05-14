#!/bin/bash

echo "Script made by rmux"
echo "===== Void Linux Arm64 Setup for Xiaomi Pad 6 ====="
echo ""
echo " ____  ____  _  ____  _  __  "
echo "| __ )|  _ \|_|/ ___|| |/ / "
echo "|  _ \| |_) | | |    | ' / "
echo "| |_) |  _ <| | |___ | . \ "
echo "|____/|_| \_\_|\____||_|\_\ "
echo "                             ᵀᴹ  "
echo ""

# Check if script is run as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

# WiFi Setup - Make it optional
echo "=== WiFi Setup ==="
echo "Note: Internet connection is required for system updates and package installation."
read -p "Do you want to set up WiFi now? (y/n): " setup_wifi

if [[ $setup_wifi == "y" || $setup_wifi == "Y" ]]; then
    echo "Please enter your WiFi SSID (network name):"
    read ssid
    echo "Please enter your WiFi password:"
    read -s password
    echo "Connecting to WiFi..."
    nmcli device wifi connect "$ssid" password "$password"

    if [ $? -eq 0 ]; then
        echo "WiFi connected successfully!"
    else
        echo "Failed to connect to WiFi. Please check your credentials."
        echo "You can set up WiFi later using the NetworkManager tool."
    fi
else
    echo "Skipping WiFi setup. You can set it up later using the NetworkManager tool."
    echo "Note: Some installation steps may fail without internet connection."
fi

# Test internet connection
if ! ping -c 1 voidlinux.org &> /dev/null; then
    echo "Warning: No internet connection detected. Some installation steps may fail."
    read -p "Continue anyway? (y/n): " continue_setup
    if [[ $continue_setup != "y" && $continue_setup != "Y" ]]; then
        echo "Setup aborted."
        exit 1
    fi
fi

# System update
echo ""
echo "=== Updating system packages ==="
echo "This may take some time depending on your internet speed..."
xbps-install -Su --noconfirm || { echo "Failed to update packages. Exiting."; exit 1; }

# Install basic packages
echo ""
echo "=== Installing basic packages ==="
xbps-install --noconfirm mesa vulkan-freedreno sudo networkmanager bluez bluez-utils xorg xorg-server xorg-xinit || { echo "Failed to install basic packages. Exiting."; exit 1; }

# Enable essential services
ln -s /etc/sv/NetworkManager /var/service/
ln -s /etc/sv/bluetoothd /var/service/

echo ""
echo "=== Setting up Bluetooth MAC address fix ==="

# Buat direktori service runit
mkdir -p /etc/sv/bt-mac
cat > /etc/sv/bt-mac/run << 'EOF'
#!/bin/sh
echo "yes" | /usr/bin/btmgmt --index 0 public-addr 00:1a:7d:da:71:13
EOF

# Tambahkan permission executable ke skrip run
chmod +x /etc/sv/bt-mac/run

# (Opsional) Tambahkan skrip log, jika ingin logging (boleh di-skip)
mkdir -p /etc/sv/bt-mac/log
cat > /etc/sv/bt-mac/log/run << 'EOF'
#!/bin/sh
exec svlogd -tt /var/log/bt-mac
EOF
chmod +x /etc/sv/bt-mac/log/run
mkdir -p /var/log/bt-mac

# Enable layanan (aktifkan layanan runit)
ln -s /etc/sv/bt-mac /var/service/

echo "Bluetooth MAC address fix service has been set up"

echo ""
echo "=== Void Linux Kernel 6.14.2 Update (Manual Install) ==="
echo "Fitur:"
echo "- Update ke Kernel 6.14.2"
echo "- Perbaikan suara (lebih stabil)"
echo "- TTY landscape"
echo "- Dukungan Landlock"
echo "- LZ4 untuk ZRAM"
echo ""

echo "Menginstall alat unduh..."
xbps-install -Sy wget unzip || { echo "Gagal menginstall wget/unzip. Lanjutkan..."; }

echo "Mengunduh modul kernel..."
wget https://github.com/BrickTM-mainline/pipa/releases/download/3.0/arch_modules_v3_0_0.zip -O /tmp/arch_modules_v3_0_0.zip || {
    echo "Gagal mengunduh modul kernel. Lewati update kernel.";
}

if [ -f /tmp/arch_modules_v3_0_0.zip ]; then
    echo "Memasang modul kernel..."
    unzip -o /tmp/arch_modules_v3_0_0.zip -d / || {
        echo "Gagal mengekstrak modul kernel. Lewati update kernel.";
    }
    rm /tmp/arch_modules_v3_0_0.zip
    echo "Modul kernel berhasil diperbarui!"
else
    echo "File modul kernel tidak ditemukan. Lewati update kernel."
fi

echo ""
echo "=== Setup Perbaikan Audio ==="
echo "Membuat file konfigurasi ALSA UCM untuk Xiaomi Pad 6..."

# Buat direktori jika belum ada
mkdir -p /usr/share/alsa/ucm2/conf.d/sm8250
mkdir -p /usr/share/alsa/ucm2/Qualcomm/sm8250

# Buat file konfigurasi utama
cat > "/usr/share/alsa/ucm2/conf.d/sm8250/Xiaomi Pad 6.conf" << EOF
Syntax 3

SectionUseCase."HiFi" {
  File "/Qualcomm/sm8250/HiFi.conf"
  Comment "HiFi quality Music."
}

SectionUseCase."HDMI" {
  File "/Qualcomm/sm8250/HDMI.conf"
  Comment "HDMI output."
}
EOF

# Buat file konfigurasi HiFi
cat > "/usr/share/alsa/ucm2/Qualcomm/sm8250/HiFi.conf" << EOF
Syntax 3

SectionVerb {
    EnableSequence [
        # Enable MultiMedia1 routing -> TERTIARY_TDM_RX_0
        cset "name='TERT_TDM_RX_0 Audio Mixer MultiMedia1' 1"
    ]

    DisableSequence [
        cset "name='TERT_TDM_RX_0 Audio Mixer MultiMedia1' 0"
    ]

    Value {
        TQ "HiFi"
    }
}

SectionDevice."Speaker" {
    Comment "Speaker playback"

    Value {
        PlaybackPriority 200
        PlaybackPCM "hw:\${CardId},0"
    }
}
EOF

echo "File konfigurasi audio berhasil dibuat!"

echo ""
echo "=== Setup Selesai ==="


echo "Your Arch Linux system on Xiaomi Pad 6 has been set up successfully!"
echo "The system will reboot in 10 seconds to apply changes."
echo "After reboot, you will be greeted with your new desktop environment."

sleep 10
reboot
