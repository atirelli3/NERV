# !/bin/bash
#
# Fprintd configuration script by @7ir3
#
# Reference: - https://wiki.archlinux.org/title/Fprint



################################################################################
# GLOBAL VARIABLES
#

POLKIT_RULES_FILE="/etc/polkit-1/rules.d/50-default.rules"  # Polkit rules file
PAM_POLKIT_FILE="/etc/pam.d/polkit-1"                       # PAM polkit file
USER=$(whoami)                                              # User
USER_GROUP=$(id -gn)                                        # User group

################################################################################
################################################################################

# ======  Fingerprint  ======
sudo pacman -S --noconfirm fprintd libfprint \
  imagemagick usbutils           # Install fprintd and dependencies

# --- Configure fprintd
sudo touch "$PAM_POLKIT_FILE"    # Create PAM polkit file
sudo bash -c "cat > $PAM_POLKIT_FILE" <<EOF
auth    sufficient    pam_fprintd.so
auth    include       system-auth
account include       system-auth
password include      system-auth
session include       system-auth
EOF                              # Add PAM polkit configuration
# Copy polkit rules file
sudo cp /usr/share/polkit-1/rules.d/50-default.rules "$POLKIT_RULES_FILE"

# --- Configure permissions
# Add user group to polkit rules
sudo sed -i "s/unix-group:wheel/unix-group:$USER_GROUP/" "$POLKIT_RULES_FILE"
sudo usermod -aG input "$USER"   # Add user to input group