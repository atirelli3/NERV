#!/bin/bash
#
# Arch Linux Installation Script by @7ir3
#
# Reference: - https://wiki.archlinux.org/title/Installation_guide
#            - https://www.dwarmstrong.org/archlinux-install/
#            - https://gist.github.com/SajoschaBE/284a844e06fa2d50c309c9a6f6cdf1d5
#            - https://gist.github.com/huntrar/e42aee630bee3295b2c671d098c81268



################################################################################
# GLOBAL VARIABLES
#
# NOTE: Edit the following variables to match your desired system configuration.

HOSTNAME="archlinux"          # Hostname

# ======  Disk  ======
# --- General
DISK="sda"                    # Disk target to install Archlinux
DISKP="sda"                   # Disk partition (if NVMe /dev/nvme0n1p if SATA repeat disk)
LABEL="archlinux"             # Root volume name (LVM)
ISSSD="yes"                   # Is SSD? (for periodic TRIM)
# --- Sizes
EFISIZE="512M"                # EFI partition size
BOOTSIZE="1G"                 # Boot partition size
SWAPSIZE="18G"                # Swap volume size (LVM)
ROOTSIZE="50G"                # Root volume size (LVM)
# --- LUKS2
CRYPTPASS="password"          # LUKS2 passphrase
CRYPTLABEL="cryptdev"         # LUKS2 volume name
# --- BtrFS
# Mount options
OPTS="rw,noatime,compress-force=zstd:1,space_cache=v2"

# ======  Hardware  ======
KERNEL="linux linux-headers"  # Kernel
CPU="intel-ucode"             # CPU microcode
GPU="intel"                   # GPU driver (intel/nvidia)

# ======  System  ======
KEYBOARD="us"                 # Keyboard layout
TIMEZONE="America/New_York"   # Timezone
LANG="it_IT.UTF-8"            # Language (en_US.UTF-8 is default)

# ======  Users  ======
ROOTPWD="password"            # Root password
USER="user"                   # User
USERPWD="password"            # User password

# ======  Extra  ======
EDITOR=vim                    # Text editor

# ======  Commands  ======
EXECREFLECTOR="reflector \
  --protocol https \
  --age 5 \
  --sort rate \
  --country , \
  --save /etc/pacman.d/mirrorlist"  # Run Reflector
REFLECTORCONF="
--save /etc/pacman.d/mirrorlist
--protocol https
--age 5
--sort rate
--country ,"                        # Reflector service configuration

################################################################################
################################################################################



################################################################################
# MAIN SCRIPT
#
# NOTE: Do not edit the following script unless you know what you are doing.

# ======  0 - Archiso configuration  ======
# --- 0.1 Kernel modules
modprobe dm-crypt                        # Cryptsetup
modprobe dm-mod                          # Mapper
rmmod pcspkr                             # Disable PC Speaker

# --- 0.2 Sytem (ISO)
loadkeys $KEYBOARD                       # Set keyboard layout
timedatectl set-timezone $TIMEZONE       # Set timezone
timedatectl set-ntp true                 # Enable NTP

# --- 0.3 Pacman (QoL)
# Enable: VerbosePkgLists, ParallelDownloads, Multilib
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 20/' /etc/pacman.conf
sed -i '/#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ {s/^#//}' /etc/pacman.conf

# --- 0.4 Update mirrorlist
$EXECREFLECTOR                           # Execute Reflector
pacman -Syy                              # Update pacman server

# --- 0.5 Update keyring
pacman -S --noconfirm archlinux-keyring  # Install (latest) keyring
pacman-key --init                        # Initialize keyring
pacman-key --populate archlinux          # Populate keyring
pacman -Syy                              # Update pacman server

# ====== 1 - Disk configuration  ======
# --- 1.1 Clear disk
wipefs -af $DISK                                   # Clear GPT tables
sgdisk --zap-all --clear $DISK                     # Clear partitions and datas
partprobe $DISK                                    # Inform kernel to changes

# --- 1.2 Partition disk
sgdisk -n 1:0:+$EFISIZE \
  -t 1:ef00 \
  -c 1:"EFI" \
  /dev/$DISK                                       # EFI - EF00 EFI System
sgdisk -n 2:0:+$BOOTSIZE \
  -t 2:8300 \
  -c 2:"Boot" \
  /dev/$DISK                                       # Boot - 8300 Linux filesystem
sgdisk -n 3:0:0 \
  -c 3:"System" \
  -t 3:8309 \
  /dev/$DISK                                       # Root - 8309 Linux LUKS
partprobe $DISK                                    # Inform kernel to changes

# --- 1.3 Zero-out partitions
cat /dev/zero > /dev/${DISKP}1                          # EFI
cat /dev/zero > /dev/${DISKP}2                          # Boot
cat /dev/zero > /dev/${DISKP}3                          # Root

# --- 1.4 LUKS2 encryption
echo -n "$CRYPTPASS" | cryptsetup -v -y luksFormat /dev/${DISKP}3 \
 --batch-mode \
 --type luks2 \
 --cipher aes-xts-plain64 \
 --key-size 512 \
 --hash sha512 \
 --pbkdf pbkdf2 \
 --pbkdf-force-iterations 100000
# Open partition
echo -n "$CRYPTPASS" | cryptsetup open /dev/${DISKP}3 $CRYPTLABEL

# --- 1.5 LVM configuration
pvcreate /dev/mapper/$CRYPTLABEL                   # Physical volume
vgcreate $LABEL /dev/mapper/$CRYPTLABEL            # Volume group
lvcreate -n swap -L $SWAPSIZE $LABEL               # Swap volume
lvcreate -n root -L $ROOTSIZE $LABEL               # Root volume
lvcreate -n home -l +100%FREE $LABEL               # Home volume

# --- 1.6 Format partitions
mkfs.fat -F32 /dev/${DISKP}1                       # EFI - FAT32
mkfs.ext4 /dev/${DISKP}2                           # Boot - EXT4
mkfs.btrfs -L root /dev/mapper/${LABEL}-root       # Root - BtrFS
mkfs.btrfs -L home /dev/mapper/${LABEL}-home       # Home - BtrFS
mkswap /dev/mapper/${LABEL}-swap                   # Swap - SWAP

# --- 1.7 Activate swap
swapon /dev/mapper/${LABEL}-swap                   # Activate
swapon -a                                          # Enable

# --- 1.8 BtrFS configurations (subvolumes)
mount /dev/mapper/${LABEL}-root /mnt               # Mount root
btrfs subvolume create /mnt/@                      # Root
btrfs subvolume create /mnt/@snapshots             # Snapshots
btrfs subvolume create /mnt/@cache                 # Cache
btrfs subvolume create /mnt/@log                   # Log
btrfs subvolume create /mnt/@tmp                   # Temp
btrfs subvolume create /mnt/@flatpak               # Flatpak (Only for system-wide apps)
umount /mnt
# Mount with BtrFS options
mount -o ${OPTS},subvol=@ /dev/mapper/${LABEL}-root /mnt
mkdir -p /mnt/{.snapshots,var/cache,var/log,var/tmp,var/lib/flatpak}
mount -o ${OPTS},subvol=@snapshots /dev/mapper/${LABEL}-root /mnt/.snapshots
mount -o ${OPTS},subvol=@cache /dev/mapper/${LABEL}-root /mnt/var/cache
mount -o ${OPTS},subvol=@log /dev/mapper/${LABEL}-root /mnt/var/log
mount -o ${OPTS},subvol=@tmp /dev/mapper/${LABEL}-root /mnt/var/tmp
mount -o ${OPTS},subvol=@flatpak /dev/mapper/${LABEL}-root /mnt/var/lib/flatpak
mount --mkdir /dev/mapper/${LABEL}-home /mnt/home  # Mount home
btrfs subvolume create /mnt/home/@home             # Home
umount /mnt/home
# Mount with BtrFS options
mount -o ${OPTS},subvol=@home /dev/mapper/${LABEL}-home /mnt/home
### --- 1.9 Mount partitions
mount --mkdir /dev/${DISKP}2 /mnt/boot             # Boot
mount --mkdir /dev/${DISKP}1 /mnt/efi              # EFI

# ====== 2 - Installation  ======
# --- 2.1 Install system packages
pacstrap -K /mnt base base-devel linux-firmware \
  $KERNEL \
  btrfs-progs cryptsetup lvm2 \
  grub efibootmgr sbctl efitools \
  networkmanager \
  $CPU \
  sudo reflector pacman-contrib     # Base system
# --- 2.2 Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab  # Generate fstab

chroot=$(cat <<EOF

# ====== 3 - Kernel image  ======
# --- 3.1 Configure mkinitcpio
# Keyfile, BtrFS module, HOOKS
sed -i 's/^FILES=.*/FILES=(\/key.bin)/' /etc/mkinitcpio.conf
sed -i '/^MODULES=/ s/)/btrfs)/' /etc/mkinitcpio.conf
sed -i '/^HOOKS=/ s/(.*)/(base udev keyboard autodetect microcode keymap consolefont modconf block encrypt lvm2 resume btrfs filesystems fsck modeset)/' /etc/mkinitcpio.conf

# --- 3.2 Generate keyfile
cd /                                           # Change directory (/)
dd bs=512 count=4 if=/dev/random of=/key.bin   # Generate keyfile
chmod 000 /key.bin                             # Secure keyfile
chmod 600 /boot/initramfs-linux*               # Secure initramfs
ROOT_PART="/dev/${DISKP}3"
# Add key to LUKS2
echo -n "$CRYPTPASS" | cryptsetup luksAddKey "$ROOT_PART" /key.bin
cryptsetup luksDump "$ROOT_PART"               # Verify key

# 3.3 Crypt /boot partition
BOOT_UUID=$(lsblk -o NAME,UUID,MOUNTPOINT | grep "/boot" | awk '{print $2}')
# Add /boot crypttab
echo "encryptedBOOT   UUID=$BOOT_UUID   none    luks,timeout=180" >> /etc/crypttab

# --- 3.4 Generate initramfs
mkinitcpio -P                                  # Generate initramfs

# ====== 4 - GRUB configurations  ======
cp /etc/default/grub /etc/default/grub.backup      # Backup GRUB

# --- 4.1 GRUB configurations
# Timeout (30s), Default boot, Save last boot, Disable submenu
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=30/" /etc/default/grub
sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" /etc/default/grub
sed -i "s/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=y/" /etc/default/grub
sed -i "s/^#GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/" /etc/default/grub

# --- 4.2 GRUB LUKS2 configurations
dev_uuid=$(blkid -s UUID -o value /dev/${DISKP}3)  # Get UUID
# Map LUKS2 device to GRUB
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 root=/dev/mapper/${LABEL}-root cryptdevice=UUID=${dev_uuid}:${CRYPTLABEL}\"|" /etc/default/grub
# Enable GRUB cryptodisk
sed -i 's/^#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub

# --- 4.3 Install GRUB
grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=GRUB --modules="tpm" --disable-shim-lock
grub-mkconfig -o /boot/grub/grub.cfg               # Generate GRUB config

# ====== 5 Secure boot  ======
sbctl create-keys                        # Create Keys
sbctl enroll-keys -m                     # Enroll Keys (with Microsoft cert, -m)
sbctl sign -s /efi/EFI/GRUB/grubx64.efi  # Sign GRUB
mkinitcpio -P --uki archlinux            # Generate initramfs (with UKI)
grub-mkconfig -o /boot/grub/grub.cfg     # Generate GRUB config

# ====== 6 - System configurations  ======
echo "$HOSTNAME" > /etc/hostname                      # Set hostname

# --- 6.1 Create /etc/hosts
cat > /etc/hosts <<EOH
127.0.0.1    localhost
::1          localhost
127.0.0.1    $HOSTNAME.localdomain $HOSTNAME
EOH

# --- 6.2 Locale configurations
sed -i "s/^#\(en_US.UTF-8\)/\1/" /etc/locale.gen     # Enable language (en_US.UTF-8)
sed -i "s/^#\(${LANG}\)/\1/" /etc/locale.gen         # Enable language (user defined)
echo "LANG=en_US.UTF-8" > /etc/locale.conf           # Set language
echo "LC_TIME=it_IT.UTF-8" >> /etc/locale.conf       # Set Local Currency time
locale-gen                                           # Generate locale
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime  # Set timezone
hwclock --systohc                                    # Sync hardware clock
echo "KEYMAP=${KEYBOARD}" > /etc/vconsole.conf       # Set keyboard layout

# ======= 6 - Network configurations  ======
# --- 6.1 Enable NetworkManager
systemctl enable NetworkManager.service              # Enable NetworkManager
systemctl enable NetworkManager-wait-online.service  # Wait for network service

# --- 6.2 NTP
systemctl enable systemd-timesyncd.service           # Enable NTP

# ======  7 - Package manager configuration (QoL)  ======
# --- 7.1 Pacman configuration
# Enable: VerbosePkgLists, ParallelDownloads = 20, Color, ILoveCandy, Multilib
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 20/' /etc/pacman.conf
sed -i '/^#Color/s/^#//' /etc/pacman.conf && sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
sed -i '/#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ {s/^#//}' /etc/pacman.conf

# --- 7.2 Makepkg configuration
# Enable: 
sed -i '/^#BUILDDIR=/s|^#||; s|^BUILDDIR=.*|BUILDDIR=/var/tmp/makepkg|' /etc/makepkg.conf
sed -i '/^#PKGEXT/s|^#||; s|^PKGEXT.*|PKGEXT='\''\.pkg\.tar'\''|' /etc/makepkg.conf
sed -i '/^#OPTIONS=/s|^#||; s|^OPTIONS=.*|OPTIONS=(docs !strip !libtool !staticlibs emptydirs zipman purge !debug lto)|' /etc/makepkg.conf
sed -i 's|-march=.* -mtune=generic|-march=native|' /etc/makepkg.conf
sed -i '/^#RUSTFLAGS=/s|^#||; s|^RUSTFLAGS=.*|RUSTFLAGS="-C opt-level=2 -C target-cpu=native"|' /etc/makepkg.conf
sed -i -e "/^#MAKEFLAGS=.*/ s|^#||; s|^MAKEFLAGS=.*|&\nMAKEFLAGS=\"-j$(($(nproc --all)-1))\"|" /etc/makepkg.conf

pacman -Syy                         # Update pacman server

# --- 7.3 Generate mirrorlist
# Backup the old list (if exist)
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
$EXECREFLECTOR                      # Execute Reflector
pacman -Syy                         # Update pacman server
systemctl enable reflector.service  # Enable Reflector service
# Reflector service configuration
tee /etc/xdg/reflector/reflector.conf <<< "$REFLECTORCONF"

# --- 7.4 Packages cleaness
systemctl enable paccache.timer     # Enable periodic cleanup

# ======  8 - Audio driver ======
pacman -S --noconfirm pipewire \
  pipewire-alsa pipewire-pulse pipewire-jack \
  wireplumber alsa-utils    # Install pipewire and dependencies

# ======  9 - Graphic driver ======
if [ "$GPU" == "intel" ]; then
  pacman -S mesa lib32-mesa \
    vulkan-intel lib32-vulkan-intel        # Install intel and dependencies
  # Add i915 to kernel MODULES
  sed -i '/^MODULES=/ s/(\(.*\))/(\1 i915)/' /etc/mkinitcpio.conf
  mkinitcpio -P --uki archlinux            # Generate initramfs (with UKI)
  grub-mkconfig -o /boot/grub/grub.cfg     # Generate GRUB config
fi

if [ "$GPU" == "nvidia" ]; then
  pacman -S --noconfirm nvidia-open-dkms \
    nvidia-utils
    lib32-nvidia-utils
    nvidia-settings 
    opencl-nvidia                          # Install nvidia-open-dkms and dependencies
  # Add nvidia, nvidia_modset, nvidia_uvm, nvidia_drm to kernel MODULES
  sed -i '/^MODULES=/ s/(\(.*\))/(\1 fbdev nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
  # Add nvidia_drm.modeset=1 to GRUB early modules
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nvidia_drm.modeset=1"/' /etc/default/grub
  # udev rules for NVIDIA
  bash -c 'echo "ACTION==\"add\", DEVPATH==\"/bus/pci/drivers/nvidia\", RUN+=\"/usr/bin/nvidia-modprobe -c 0 -u\"" > /etc/udev/rules.d/70-nvidia.rules'
  # Add NVIDIA power management option
  bash -c 'echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" > /etc/modprobe.d/nvidia-power-mgmt.conf'
  mkinitcpio -P --uki archlinux            # Generate initramfs (with UKI)
  grub-mkconfig -o /boot/grub/grub.cfg     # Generate GRUB config
fi 

# ======  10 - User configurations  ======
# --- 10.1 Root password
echo "root:$ROOTPWD" | chpasswd

# --- 10.2 Create user
useradd -m -G wheel -s /bin/bash $USER     # Create user
echo "$USER:$USERPWD" | chpasswd           # Set password

# --- 10.3 Sudo configurations
sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers

# ======  11 - Extra packages  ======
pacman -S --noconfirm bash-completion man-db \
  htop wget curl \
  mlocate pkgfile \
  $EDITOR    # Install extra packages and dependencies

# --- 11.1 Set environment
echo "EDITOR=$EDITOR" >> /etc/environment    # Set default editor
echo "VISUAL=$EDITOR" >> /etc/environment    # Set default visual editor
# Enable SSD TRIM
[[ "${ISSSD:-no}" == "yes" ]] && systemctl enable fstrim.timer
pkgfile --update                             # Update pkgfile
block="
if [[ -f /usr/share/doc/pkgfile/command-not-found.bash ]]; then
    . /usr/share/doc/pkgfile/command-not-found.bash
fi
"
echo "$block" >> ~/.bashrc                   # Command not found (add to bashrc)

exit
EOF
)

# --- 2.3 Chroot
echo "$chroot" | arch-chroot /mnt /bin/bash



################################################################################
# END SCRIPT

umount -R /mnt  # Unmount partitions
swapoff -a      # Deactivate swap
reboot          # Reboot system