#!/usr/bin/env bash

# Arch Stage2

if [[ $1 == "" ]] || [[ $1 == "-h" ]]; then
    echo "You must provide a hostname"
    echo "Usage: $0 <hostname.domain> (root partition)"
    echo "Script should be used inside a chroot environment"
    exit 1
fi

# Fix potential pacman keyring bug
echo "Fixing potential pacman keyring bug"
pacman-key --init
pacman-key --populate archlinux

# Timezone
echo "Setting timezone to America/Sao_Paulo"
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Locales
echo "Setting locales to en_US.UTF-8 and pt_BR.UTF-8"
sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen
sed -i '/pt_BR.UTF-8/s/^#//g' /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
locale-gen

# TTY
echo "Setting TTY to br-abnt2 with a bigger font"
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
echo "FONT=ter-124b" >> /etc/vconsole.conf

# Hostname
echo "Setting hostname to $1"
echo $1 > /etc/hostname

# Pacman
echo "Setting up Pacman"
sed -i '/Color/s/^#//g' /etc/pacman.conf
sed -i '/ParallelDownloads/s/^#//g' /etc/pacman.conf

# MakePKG
echo "Setting up MakePKG"
sed -i 's/COMPRESSZST.*/COMPRESSZSTD=(cat -)/' /etc/makepkg.conf
sed -i 's/purge debug/purge !debug/' /etc/makepkg.conf

# MKInitCPIO
echo "Setting up MKInitCPIO"
cat << EOF > /etc/mkinitcpio.conf

MODULES=(btrfs)
BINARIES=()
FILES=()
HOOKS=(systemd autodetect microcode modconf kms keyboard sd-vconsole block)
COMPRESSION="cat"

EOF

# Presets
echo "Disabling 'fallback' preset"
sed -i "s/PRESETS=.*/PRESETS=('default')/" /etc/mkinitcpio.d/linux-zen.preset

# Install packages
echo "Installing packages"
pacman -Syu --noconfirm \
    --needed \
    axel \
    base-devel \
    btrfs-progs \
    busybox \
    curl \
    git \
    grub \
    htop \
    inxi \
    lsd \
    nano \
    networkmanager \
    sshfs \
    sudo \
    terminus-font \
    zsh \

# Allow sudo for wheel group
echo "Allowing sudo for wheel group"
sed -i '/%wheel ALL=(ALL:ALL) ALL/s/^#//g' /etc/sudoers

# Enable services
echo "Enabling basic services..."
echo "SSHD"
systemctl enable sshd
echo "TimesyncD"
systemctl enable systemd-timesyncd
echo "NetworkManager"
systemctl enable NetworkManager

echo "Allowing SSH root login"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# OH-MY-ZSH for root
echo "Installing oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

echo "Changinh shell to zsh for root"
chsh -s $(which zsh) root

echo "Setting ZSH_THEME to random"
sed -i 's/ZSH_THEME=".*"/ZSH_THEME="random"/' /root/.zshrc

echo "Adding update alias"
echo 'alias update="pacman -Syyuu --noconfirm"' >> /root/.zshrc

echo "Adding LSD aliases"
cat << EOF >> /root/.zshrc
alias ls="lsd"
alias l='ls -l'
alias la='ls -a'
alias lla='ls -la'
alias lt='ls --tree'
EOF

# Microcode
echo "Installing microcode"
if [[ $(lscpu | grep GenuineIntel) ]]; then
    pacman -S --noconfirm --needed intel-ucode
elif [[ $(lscpu | grep AuthenticAMD) ]]; then
    pacman -S --noconfirm --needed amd-ucode
else
    echo "Unknown CPU, microcode not installed"
fi

# Bootloader
echo "Configuring Bootloader"
if [[ -d /sys/firmware/efi/efivars ]]; then
    echo "Installing systemd-boot for UEFI"
    # pacman -S --noconfirm --needed efibootmgr
    bootctl --path=/boot install
    systemctl enable systemd-boot-update
    echo "Configuring systemd-boot"
    echo "default @saved" > /boot/loader/loader.conf
    echo "beep 1" >> /boot/loader/loader.conf
    
    echo "Adding Arch Linux entry"

    echo "title Arch Linux" > /boot/loader/entries/arch.conf
    echo "linux /vmlinuz-linux-zen" >> /boot/loader/entries/arch.conf
    echo "initrd /initramfs-linux-zen.img" >> /boot/loader/entries/arch.conf
    echo "options root=PARTUUID=$(blkid -s PARTUUID -o value $2) rootflags=subvol=system rw loglevel=3 net.ifnames=0 biosdevname=0 mitigations=off" >> /boot/loader/entries/arch.conf

    echo "Adding Arch Linux Snap entry"

    echo "title Arch Linux Snap" > /boot/loader/entries/arch-snap.conf
    echo "linux /vmlinuz-linux-zen" >> /boot/loader/entries/arch-snap.conf
    echo "initrd /initramfs-linux-zen.img" >> /boot/loader/entries/arch-snap.conf
    echo "options root=PARTUUID=$(blkid -s PARTUUID -o value $2) rootflags=subvol=snap rw loglevel=3 net.ifnames=0 biosdevname=0 mitigations=off" >> /boot/loader/entries/arch-snap.conf

else
    echo "Configuring GRUB for BIOS"
    mkdir /boot/grub -p
    sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 net.ifnames=0 biosdevname=0 mitigations=off"/' /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "ATENTION!"
    echo "You need to manually install GRUB for BIOS"
    echo "grub-install --target=i386-pc /dev/XXX"
    echo "ATTENTION!"
fi

echo "Downloading setup-desktop"
curl -s -L -o /root/setup-desktop.sh https://lzart.com.br/setup-desktop.sh
chmod +x /root/setup-desktop.sh
echo "To install a desktop enviroment, reboot and run 'bash setup-desktop.sh'"

# Root password
echo "Please set root's password"
passwd

# System Snapshot
echo "Creating system snapshot"
mount $2 /mnt
btrfs subvolume snapshot /mnt/system /mnt/snap
umount /mnt
echo "In case you need to rollback to the 'fresh install' state, you can use the snapshot"
echo "At systemd-boot screen, press 'e' on the Arch Linux entry and change the subvol from 'system' to 'snap'"

# Done
echo "Done! You can now exit the chroot environment and reboot"
