#!/usr/bin/env bash

set -e

if [[ $1 == "" || $1 == "-h" ]]; then
    echo "Usage: $0 <desktop-environment>"
    echo "Supported desktop environments: gnome, kde, xfce, kodi"
    echo "Kodi has autologin enabled by default."
    exit 1
fi

pipewire=(
    "pipewire"
    "pipewire-alsa"
    "pipewire-jack"
    "pipewire-pulse"
)

pulseaudio=(
    "pulseaudio"
    "pulseaudio-alsa"
    "pulseaudio-jack"
)

common_apps=(
    "alsa-utils"
    "firefox"
    "pavucontrol"
    "p7zip"
    "unrar"
    "unzip"
    "zip"
    "noto-fonts-emoji"
    "fastfetch"
    "sof-firmware"
    "ttf-nerd-fonts-symbols"
)

xfce_apps=(
    "xarchiver"
    "xfce4"
    "xfce4-terminal"
    "xfce4-screenshooter"
    "xfce4-screensaver"
    "ristretto"
    "thunar-archive-plugin"
    "mousepad"
    "xfce4-whiskermenu-plugin"
    "gnome-keyring"
    "xfce4-pulseaudio-plugin"
    "lightdm-gtk-greeter"
    "xfce4-taskmanager"
    "xfce4-clipman-plugin"
    "network-manager-applet"
    "gvfs"
    "gvfs-afc"
    "gvfs-mtp"
    "gvfs-gphoto2"
    "gvfs-smb"
    "gvfs-wsdd"
)

gnome_apps=(
    "gnome"
    "gnome-tweaks"
)

kde_apps=(
    "plasma"
    "konsole"
)

kodi_apps=(
    "kodi"
    "lightdm"
    "pulseaudio"
    "pulseaudio-alsa"
    "pulseaudio-jack"
)

install_gnome() {
    echo "Installing GNOME..."
    pacman -Sy --noconfirm --needed "${gnome_apps[@]}" "${common_apps[@]}" "${pipewire[@]}"

    create_user

    echo "Enabling gdm..."
    systemctl enable gdm
}

install_kde() {
    echo "Installing KDE..."
    pacman -Sy --noconfirm --needed "${kde_apps[@]}" "${common_apps[@]}" "${pulseaudio[@]}"

    create_user

    echo "Enabling sddm..."
    systemctl enable sddm
}

install_xfce() {
    echo "Installing XFCE..."
    pacman -Sy --noconfirm --needed "${xfce_apps[@]}" "${common_apps[@]}" "${pulseaudio[@]}"

    create_user

    echo "Enabling lightdm..."
    systemctl enable lightdm
}

install_kodi() {
    echo "Installing Kodi..."
    pacman -Sy --noconfirm --needed "${kodi_apps[@]}" "${pulseaudio[@]}"

    create_user

    echo "Setting up lightdm autologin..."
    sed -i "s/#autologin-user=/autologin-user=$username/" /etc/lightdm/lightdm.conf
    sed -i 's/#autologin-session=/autologin-session=kodi/' /etc/lightdm/lightdm.conf
    groupadd -r autologin
    gpasswd -a $username autologin

    echo "Enabling lightdm..."
    systemctl enable lightdm
}

create_user() {
    echo "Creating user..."
    echo "Input username:"
    read username
    export username

    useradd -m -G audio,video,wheel $username
    
    echo input password for $username
    passwd $username
}

case $1 in
    gnome)
        install_gnome
        ;;
    kde)
        install_kde
        ;;
    xfce)
        install_xfce
        ;;
    kodi)
        install_kodi
        ;;
    *)
        echo "Unsupported desktop environment: $1"
        exit 1
        ;;
esac

echo "Installation finished, you should now reboot."