# !/bin/bash
#
# Grub theme script by @7ir3
#
# Reference: - https://k1ng.dev/distro-grub-themes/installation



################################################################################
# GLOBAL VARIABLES
#
# NOTE: Edit the following variables to match your desired system configuration.

RESOLUTION="1920x1080"           # Screen resolution
BOOT_GRUB_LOCATION="/boot/grub"  # Grub location
THEMENAME="archlinux"            # Theme name

################################################################################
################################################################################

# ======  Grub Theme  ======
# --- Clone repository
git clone https://github.com/AdisonCavani/distro-grub-themes.git /tmp/grub-themes
sudo mkdir ${BOOT_GRUB_LOCATION}/themes    # Create GRUB themes directory
cd /tmp/grub-themes/themes                 # Change to themes directory
# Copy theme to GRUB
sudo tar -C ${BOOT_GRUB_LOCATION}/themes/${THEMENAME} -xf ${THEMENAME}.tar
# --- Edit GRUB configuration
sudo sed -i "s/^#GRUB_GFXMODE=.*/GRUB_GFXMODE=$RESOLUTION/" /etc/default/grub
sudo sed -i 's/^GRUB_TERMINAL_OUTPUT="console"/#GRUB_TERMINAL_OUTPUT="console"/' /etc/default/grub
# --- Apply theme
themeline="GRUB_THEME=\"$BOOT_GRUB_LOCATION/themes/$THEMENAME/theme.txt\""
sudo sed -i "s|^GRUB_THEME=.*|$THEME_LINE|" /etc/default/grub
sudo mkinitcpio -P --uki archlinux         # Generate initramfs (with UKI)
sudo grub-mkconfig -o /boot/grub/grub.cfg  # Generate GRUB config
# --- Clean up
cd -                                       # Return to previous directory
rm -rf /tmp/grub-themes                    # Clean up



################################################################################
# END SCRIPT