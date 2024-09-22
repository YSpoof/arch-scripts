#!/usr/bin/env bash

# ZArch Install A.K.A Stage1
if [[ $1 == "" || $1 == "-h" || $2 == "" ]]; then
    echo "Usage: $0 </dev/disk> <hostname.domain>"
    echo "Currently only supports UEFI"
    exit 1
fi

# Confirm with user
read -p "Are you sure you want to continue ? This will erase $1? [y/N] " -n 1 -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo " Aborted by user"
    exit 1
fi

# Umount partitions
echo "Umounting partitions"
umount -R /mnt

# Fix potential pacman keyring bug
echo "Fixing potential pacman keyring bug"
pacman-key --init
pacman-key --populate archlinux

# Tweak pacman.conf
echo "Tweaking Pacman"
sed -i '/Color/s/^#//g' /etc/pacman.conf
sed -i '/ParallelDownloads/s/^#//g' /etc/pacman.conf

# Update mirrors
echo "Updating mirrors"
echo 'Server = https://archlinux.c3sl.ufpr.br/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo 'Server = https://br.mirrors.cicku.me/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
echo 'Server = https://mirror.ufscar.br/archlinux/$repo/os/$arch' >> /etc/pacman.d/mirrorlist
pacman -Syy

# Erase disk
echo "Erasing disk"
blkdiscard -f $1
sgdisk --zap-all $1

# Create partitions 1G efi and the rest root btrfs
echo "Creating partitions"
sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" $1
sgdisk -n 2:0:0 -t 2:8300 -c 2:"RootFS" $1

# Format partitions
echo "Formatting partitions"
if [[ $1 == *nvme* || $1 == *mmcblk* ]]; then
    mkfs.vfat -n EFI -F32 ${1}p1
    mkfs.btrfs -L RootFS -f ${1}p2
else
    mkfs.vfat -n EFI -F32 ${1}1
    mkfs.btrfs -L RootFS -f ${1}2
fi

# Mount partitions
echo "Mounting btrfs partition"
if [[ $1 == *nvme* || $1 == *mmcblk* ]]; then
    mount ${1}p2 /mnt
else
    mount ${1}2 /mnt
fi

# Create subvolume
echo "Creating subvolume"
btrfs subvolume create /mnt/system

# Remount partition
echo "Remounting partition with subvolume"
umount /mnt
if [[ $1 == *nvme* || $1 == *mmcblk* ]]; then
    mount -o defaults,compress=zstd:3,subvol=system ${1}p2 /mnt
else
    mount -o defaults,compress=zstd:3,subvol=system ${1}2 /mnt
fi

# Mount boot partition
echo "Mouting boot partition"
mkdir -p /mnt/boot
if [[ $1 == *nvme* || $1 == *mmcblk* ]]; then
    mount ${1}p1 /mnt/boot
else
    mount ${1}1 /mnt/boot
fi

# Install base system
echo "Installing base system"
pacstrap -K /mnt base btrfs-progs linux-zen linux-firmware

# Generate fstab
echo "Generating fstab"
genfstab -U /mnt > /mnt/etc/fstab

# Stage 2
echo "Downloading and running stage 2"
curl -s -L -o /mnt/stage2.sh https://lzart.com.br/stage2.sh
chmod +x /mnt/stage2.sh
if [[ $1 == *nvme* || $1 == *mmcblk* ]]; then
    arch-chroot /mnt /stage2.sh $2 ${1}p2
else
    arch-chroot /mnt /stage2.sh $2 ${1}2
fi
