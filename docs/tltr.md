# Archlinux installation - TLTR

> [!NOTE]
> Just copy and past the commands in the blocks

## Installation

1. Configure archiso
2. Partition and format disk
3. Install base system

``` bash
export disk="/dev/nvme0n1"
export diskp="/dev/nvme0n1p"
export lvm_label="archlinux"
export lvm_rootsize="50G"
export lvm_swapsize="18G"
export btrfs_opts="rw,noatime,compress-force=zstd:1,space_cache=v2"
export key="changeme"
export cryptlabel="cryptdev"
export pkgs="base base-devel linux-firmware \
  linux-zen linux-zen-headers \
  btrfs-progs cryptsetup lvm2 \
  networkmanager sudo \
  grub efibootmgr sbctl \
  intel-ucode"

modprobe dm-crypt
modprobe dm-mod
rmmod pcspkr

timedatectl set-timezone "Europe/Rome"
timedatectl set-ntp true

sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 20/' /etc/pacman.conf
sed -i '/#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ {s/^#//}' /etc/pacman.conf

reflector --protocol https --age 6 --sort rate --country Italy,Germany,France, --save /etc/pacman.d/mirrorlist
pacman -Syy

pacman -S --noconfirm archlinux-keyring
pacman-key --init
pacman-key --populate archlinux
pacman -Syy

wipefs -af "${disk}"
sgdisk --zap-all --clear "${disk}"
partprobe "${disk}"

sgdisk -n 1:0:+512M -t 1:ef00 "${disk}"
sgdisk -n 2:0:+4G -t 2:8300 "${disk}"
sgdisk -n 3:0:0 -t 3:8309 "${disk}"
partprobe "${disk}"

cat /dev/zero > "${diskp}1"
cat /dev/zero > "${diskp}2"
cat /dev/zero > "${diskp}3"

echo -n "${key}" | cryptsetup -v -y luksFormat "${diskp}3" \
  --batch-mode \
  --type luks2 \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --pbkdf pbkdf2 \
  --pbkdf-force-iterations 100000
echo -n "${key}" | cryptsetup open "${diskp}3" "${cryptlabel}"

pvcreate /dev/mapper/"${cryptlabel}"
vgcreate "${lvm_label}" /dev/mapper/"${cryptlabel}"
lvcreate -n swap -L "${lvm_swapsize}" "${lvm_label}"
lvcreate -n root -L "${lvm_rootsize}" "${lvm_label}"
lvcreate -n home -l +100%FREE "${lvm_label}"

mkfs.fat -F32 "${diskp}1"
mkfs.ext4 "${diskp}2"
mkfs.btrfs -L root /dev/mapper/"${lvm_label}"-root
mkfs.btrfs -L home /dev/mapper/"${lvm_label}"-home

mkswap /dev/mapper/"${lvm_label}"-swap
swapon /dev/mapper/"${lvm_label}"-swap

mount /dev/mapper/"${lvm_label}"-root /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@cache
btrfs subvolume create /mnt/@log
btrfs subvolume create /mnt/@tmp
btrfs subvolume create /mnt/@flatpak
umount /mnt

mount -o "${btrfs_opts}",subvol=@ /dev/mapper/"${lvm_label}"-root /mnt
mkdir -p /mnt/{.snapshots,var/cache,var/log,var/tmp,var/lib/flatpak}
mount -o "${btrfs_opts}",subvol=@snapshots /dev/mapper/"${lvm_label}"-root /mnt/.snapshots
mount -o "${btrfs_opts}",subvol=@cache /dev/mapper/"${lvm_label}"-root /mnt/var/cache
mount -o "${btrfs_opts}",subvol=@log /dev/mapper/"${lvm_label}"-root /mnt/var/log
mount -o "${btrfs_opts}",subvol=@tmp /dev/mapper/"${lvm_label}"-root /mnt/var/tmp
mount -o "${btrfs_opts}",subvol=@flatpak /dev/mapper/"${lvm_label}"-root /mnt/var/lib/flatpak

mount --mkdir /dev/mapper/"${lvm_label}"-home /mnt/home
btrfs subvolume create /mnt/home/@home
umount /mnt/home
mount -o "${btrfs_opts}",subvol=@home /dev/mapper/"${lvm_label}"-home /mnt/home

mount --mkdir "${diskp}2" /mnt/boot
mount --mkdir "${diskp}1" /mnt/efi

pacstrap -K /mnt "${pkgs}"
genfstab -U -p /mnt >> /mnt/etc/fstab
arch-chroot /mnt /bin/bash
```

## chroot

1. Generate kernel image
2. Install and configure bootloader (GRUB)
3. Secure boot
4. Configure the system (locale)
5. Configure users
6. Archlinux QoL
7. Services
8. Extra packages

``` bash
export hostname="archlinux"
export keyboard="us"
export disk="/dev/nvme0n1"
export diskp="/dev/nvme0n1p"
export lvm_label="archlinux"
export key="changeme"
export cryptlabel="cryptdev"
export user="user"
export passwd="password"
export rootpasswd="password"
export extrapkgs="bash-completion vim man-db pkgfile"

sed -i 's/^FILES=.*/FILES=(\/key.bin)/' /etc/mkinitcpio.conf
sed -i '/^MODULES=/ s/)/btrfs)/' /etc/mkinitcpio.conf
sed -i '/^HOOKS=/ s/(.*)/(base udev keyboard autodetect microcode keymap consolefont modconf block encrypt lvm2 resume btrfs filesystems fsck)/' /etc/mkinitcpio.conf
cd /
dd bs=512 count=4 if=/dev/random of=/key.bin
chmod 000 /key.bin
chmod 600 /boot/initramfs-linux*
echo -n "${key}" | cryptsetup luksAddKey "${diskp}3" /key.bin
cryptsetup luksDump "${diskp}3"
BOOT_UUID=$(lsblk -o NAME,UUID,MOUNTPOINT | grep "/boot" | awk '{print $2}')
echo "encryptedBOOT   UUID=$BOOT_UUID   none    luks,timeout=180" >> /etc/crypttab
mkinitcpio -P

cp /etc/default/grub /etc/default/grub.backup
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=30/" /etc/default/grub
sed -i "s/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/" /etc/default/grub
sed -i "s/^#GRUB_SAVEDEFAULT=.*/GRUB_SAVEDEFAULT=y/" /etc/default/grub
sed -i "s/^#GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=y/" /etc/default/grub
export dev_uuid=$(blkid -s UUID -o value "${diskp}3")
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"loglevel=3 root=/dev/mapper/${lvm_label}-root cryptdevice=UUID=${dev_uuid}:${cryptlabel}\"|" /etc/default/grub
sed -i 's/^#GRUB_ENABLE_CRYPTODISK=y/GRUB_ENABLE_CRYPTODISK=y/' /etc/default/grub
grub-install --target=x86_64-efi \
  --efi-directory=/efi \
  --boot-directory=/boot \
  --bootloader-id=GRUB \
  --modules="tpm" \
  --disable-shim-lock
grub-mkconfig -o /boot/grub/grub.cfg

sbctl create-keys
sbctl enroll-keys -m
sbctl sign -s /efi/EFI/GRUB/grubx64.efi
mkinitcpio -P --uki archlinux
grub-mkconfig -o /boot/grub/grub.cfg

cat > /etc/hosts << EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
EOF
sed -i "s/^#\(en_US.UTF-8\)/\1/" /etc/locale.gen
sed -i "s/^#\(it_IT.UTF-8\)/\1/" /etc/locale.gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "LC_TIME=it_IT.UTF-8" >> /etc/locale.conf
echo "KEYMAP=${keyboard}" > /etc/vconsole.conf
locale-gen
ln -sf /usr/share/zoneinfo/Europe/Rome /etc/localtime
hwclock --systohc

echo "root:${rootpasswd}" | chpasswd
useradd -m -G wheel -s /bin/bash "${user}"
echo "${user}:${passwd}" | chpasswd
sed -i "s/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/" /etc/sudoers
echo "foo ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sudoer_"${user}"

sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 20/' /etc/pacman.conf
sed -i '/^#Color/s/^#//' /etc/pacman.conf && sed -i '/^Color/a ILoveCandy' /etc/pacman.conf
sed -i '/#\[multilib\]/,/^#Include = \/etc\/pacman.d\/mirrorlist/ {s/^#//}' /etc/pacman.conf

sed -i '/^#BUILDDIR=/s|^#||; s|^BUILDDIR=.*|BUILDDIR=/var/tmp/makepkg|' /etc/makepkg.conf
sed -i '/^#PKGEXT/s|^#||; s|^PKGEXT.*|PKGEXT='\''\.pkg\.tar'\''|' /etc/makepkg.conf
sed -i '/^#OPTIONS=/s|^#||; s|^OPTIONS=.*|OPTIONS=(docs !strip !libtool !staticlibs emptydirs zipman purge !debug lto)|' /etc/makepkg.conf
sed -i 's|-march=.* -mtune=generic|-march=native|' /etc/makepkg.conf
sed -i '/^#RUSTFLAGS=/s|^#||; s|^RUSTFLAGS=.*|RUSTFLAGS="-C opt-level=2 -C target-cpu=native"|' /etc/makepkg.conf
sed -i -e "/^#MAKEFLAGS=.*/ s|^#||; s|^MAKEFLAGS=.*|&\nMAKEFLAGS=\"-j$(($(nproc --all)-1))\"|" /etc/makepkg.conf

pacman -S --noconfirm reflector
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
reflector --country Italy,Germany,France, --protocol https --age 6 --sort rate --save /etc/pacman.d/mirrorlist

systemctl enable systemd-timesyncd.service
systemctl enable NetworkManager.service
systemctl enable NetworkManager-wait-online.service
pacman -S --noconfirm pacman-contrib
systemctl enable paccache.timer
systemctl enable reflector.service
pacman -S --noconfirm openssh
systemctl enable sshd.service

pacman -S --noconfirm "${extrapkgs}"
```
