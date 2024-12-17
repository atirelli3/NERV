#!/bin/bash
#
# Hardening script by @7ir3
#
# Reference: - https://www.youtube.com/watch?v=ivXTv5ate-M



################################################################################
# GLOBAL VARIABLES

################################################################################
################################################################################

# ======  Hardening  ======
sudo pacman -S --noconfirm ufw      # Install UFW and dependencies
# todo: extend for other OS (macOS, etc)
# --- UFW

# --- Kernel parameters
sudo bash -c "cat << EOF > /etc/sysctl.d/90-network.conf
# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Enable SYN flood protection
net.ipv4.tcp_syncookies = 1

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Do not send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
EOF"                  # Add kernel parameters
sudo sysctl --system  # Apply kernel parameters



################################################################################
# END SCRIPT