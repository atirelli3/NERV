#!/bin/bash
#
# Arch Linux post-installation script by @7ir3
#
# Reference: - https://www.dwarmstrong.org/btrfs-snapshots-rollbacks/
#            - https://wiki.archlinux.org/title/AUR_helpers
#            - https://github.com/morganamilo/paru



################################################################################
# GLOBAL VARIABLES
#
# NOTE: Edit the following variables to match your desired system configuration.

FLATPAK=(
  "com.raggesilver.BlackBox"
  "com.mattjakeman.ExtensionManager"
  "org.gnome.TextEditor"
  "org.gnome.Calculator"
  "org.gnome.Calendar"
  "org.gnome.Papers"
  "io.github.zen_browser.zen"
  "com.brave.Browser"
  "com.vscodium.codium"
)                                        # Flatpak applications
# NOTE: Applications such as Firefox, Thunderbird, etc. are not included
# in the list because they are already installed by default.
USER=$(whoami)                           # User
PDF_DIR="$HOME/Downloads"                # PDF save directory
CUPS_PDF_CONF="/etc/cups/cups-pdf.conf"  # CUPS PDF configuration file

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

# --- 1.1 AUR packages (QoL)
paru -S --noconfirm  aur-out-of-date \
  pkgoutofdate \
  aur-talk                                              # AUR packages

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
ALLOW_USERS="$USER"
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
sudo sed -i '/^MODULES=/ s/(\(.*\))/(\1 grub-btrfs-overlayfs)/' /etc/mkinitcpio.conf
sudo mkinitcpio -P --uki archlinux                   # Generate initramfs (with UKI)
sudo grub-mkconfig -o /boot/grub/grub.cfg            # Generate GRUB config

# ======  4 - CUPS  ======
sudo pacman -S --noconfirm cups cups-pdf    # Install CUPS and dependencies
sudo systemctl enable cups.service          # Enable CUPS

# --- 4.1 CUPS configuration (PDF saving)
if grep -q "^Out .*" "$CUPS_PDF_CONF"; then
  sudo sed -i "s|^Out .*|Out $PDF_DIR|" "$CUPS_PDF_CONF"
else
  echo "Out $PDF_DIR" | sudo tee -a "$CUPS_PDF_CONF"
fi

# ======  5 - Bluetooth  ======
sudo pacman -S --noconfirm bluez bluez-utils  # Install Bluez and dependencies

# --- 5.1 Bluetooth configuration
# --- ControllerMode = dual
# Uncomment and set ControllerMode = dual
sudo sed -i 's/^\s*#*\s*ControllerMode\s*=.*/ControllerMode = dual/' "$BLUETOOTH_CONF"
# Add ControllerMode = dual if it does not exist
if ! grep -q "^ControllerMode = dual" "$BLUETOOTH_CONF"; then
  echo "ControllerMode = dual" | sudo tee -a "$BLUETOOTH_CONF" > /dev/null
fi
# --- Kernel Experimental
# Check if [General] exists in the configuration file
if ! grep -q "^\[General\]" "$BLUETOOTH_CONF"; then
  echo -e "\n[General]" | sudo tee -a "$BLUETOOTH_CONF" > /dev/null
fi

# Modify Experimental = true
sudo sed -i '/^\[General\]/,/^\[/{s/^\s*#*\s*Experimental\s*=.*/Experimental = true/}' "$BLUETOOTH_CONF"

# Add Experimental = true if it does not exist
if ! grep -A1 "^\[General\]" "$BLUETOOTH_CONF" | grep -q "^Experimental = true"; then
  sudo sed -i '/^\[General\]/a Experimental = true' "$BLUETOOTH_CONF"
fi
sudo systemctl enable bluetooth               # Enable Bluetooth

# ======  6 - GNOME  ======



################################################################################
# END SCRIPT

sudo reboot now  # Reboot system