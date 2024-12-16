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

# ======  3 - SSH  ======
# Reference: - https://www.dwarmstrong.org/ssh-keys/
#            - https://wiki.archlinux.org/title/OpenSSH
sudo pacman -S --noconfirm openssh  # Install OpenSSH
mkdir ~/.ssh                        # Create SSH directory
chmod 700 ~/.ssh                    # Set permissions
touch ~/.ssh/authorized_keys        # Create authorized_keys file
chmod 600 ~/.ssh/authorized_keys    # Set permissions
# --- 3.1 Generate SSH key
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)-$(date -I)"