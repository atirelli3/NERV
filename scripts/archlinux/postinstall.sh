#!/bin/bash
#
# Arch Linux post-installation script by @7ir3

# 0. Preparation
# 
# 1. AUR helper
#
# 2. BtrFS snapshot
#   2.1 snapper
#   2.2 grub-btrfs
#
# 3. SSH
#   3.1 Install OpenSSH
#   3.2 Generate SSH key
#
# 4. GNOME
#   4.1 Install (minimal) GNOME
#   4.2 Minimal dconf configuration
#   4.3 Install GNOME extensions
#   4.4 Install applications (flatpak)
#
# 5. Extra packages
#
# 6. Dotfiles (if specified)



################################################################################
# GLOBAL VARIABLES
#
# NOTE: Edit the following variables to match your desired system configuration.

# ======  Users  ======
user="user"                   # User

# ======  Others  ======
github="email@email.it"       # GitHub email



################################################################################
################################################################################



################################################################################
# MAIN SCRIPT
#
# NOTE: Do not edit the following script unless you know what you are doing.

# ======  0 - Preparation  ======
sudo pacman -Syyu --noconfirm  # Update system

# ======  1 - AUR helper  ======
sudo pacman -S --noconfirm base-devel git               # Install packages
git clone https://aur.archlinux.org/paru.git /tmp/paru  # Clone AUR helper
cd /tmp/paru && makepkg -si --noconfirm                 # Build and install AUR helper
cd -                                                    # Return to previous directory
rm -rf /tmp/paru                                        # Clean up
paru --noconfirm -Syyu                                  # Update AUR helper

# ======  2 - BtrFS snapshot  ======
# Reference: - https://www.dwarmstrong.org/btrfs-snapshots-rollbacks/
sudo pacman -S --noconfirm snapper snap-pac          # Packages

# --- 2.1 Snapshot configuration
sudo umount /.snapshots                              # Unmount the subvolume
sudo rm -rf /.snapshots                              # Remove the mountpoint
sudo snapper -c root create-config /                 # Create a '/' config

# --- 2.2 Setup @snapshots
sudo btrfs subvolume delete .snapshots               # Delete snapper-generated subvolume
sudo mkdir /.snapshots                               # Re-create
sudo mount -a                                        # Re-mount
sudo chmod 750 /.snapshots                           # Set permissions
sudo chown :wheel /.snapshots                        # Allow 'wheel' to browse through snapshots

# --- 2.3 Automatic timeline snapshots
# Timed auto-snapshots config
sudo tee "/etc/snapper/configs/root" > /dev/null << EOF
ALLOW_USERS="$user"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="5"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EOF
sudo systemctl enable --now snapper-timeline.timer   # Automatic snapshot timeline
sudo systemctl enable --now snapper-cleanup.timer    # Periodically clean up

# --- 2.4 Skip indexing of @snapshots by 'locate'
sudo tee -a "/etc/updatedb.conf" > /dev/null << EOF
PRUNENAMES=".snapshots"
EOF

# --- 2.5 GRUB-BtrFS
sudo pacman -S --noconfirm grub-btrfs inotify-tools  # Packages
# Set the location of the GRUB directory
sudo sed -i 's|^#GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME="/boot/grub"|' /etc/default/grub-btrfs/config
sudo systemctl enable --now grub-btrfs.path          # Auto-regenerate grub-btrfs.cfg
# Add the hook
sed -i '/^MODULES=/ s/(\(.*\))/(\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
mkinitcpio -P --uki archlinux                        # Generate initramfs (with UKI)
grub-mkconfig -o /boot/grub/grub.cfg                 # Generate GRUB config

# ======  3 - SSH  ======
# Reference: - https://www.dwarmstrong.org/ssh-keys/
#            - https://wiki.archlinux.org/title/OpenSSH
sudo pacman -S --noconfirm openssh  # Install OpenSSH
mkdir -p ~/.ssh/keyring             # Create SSH directory and keyring
chmod 700 ~/.ssh                    # Set permissions
chmod 700 ~/.ssh/keyring            # Set permissions
touch ~/.ssh/authorized_keys        # Create authorized_keys file
chmod 600 ~/.ssh/authorized_keys    # Set permissions

# --- 3.1 Generate SSH key
# - Host
# - GitHub
mkdir ~/.ssh/keyring/"$(whoami)@$(hostname)"
chmod 700 ~/.ssh/keyring/"$(whoami)@$(hostname)"
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/keyring/"$(whoami)@$(hostname)"
mkdir ~/.ssh/keyring/github
chmod 700 ~/.ssh/keyring/github
ssh-keygen -t ed25519 -C "$github" -f ~/.ssh/keyring/github