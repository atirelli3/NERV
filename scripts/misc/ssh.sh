# !/bin/bash
#
# OpenSSH configuration script by @7ir3
#
# Reference: - https://www.dwarmstrong.org/ssh-keys/
#            - https://wiki.archlinux.org/title/OpenSSH



################################################################################
# GLOBAL VARIABLES
#

KEYRINGPATH="~/.ssh/keyring"       # SSH keyring path
HOSTKEY="$(whoami)@$(hostname)"    # Host key
GITHUBKEY="email@email.com"        # GitHub key

################################################################################

# ======  SSH  ======
sudo pacman -S --noconfirm openssh      # Install OpenSSH and dependencies
# todo: extend for other OS (macOS, etc)

# --- SSH Structure
mkdir -p $KEYRINGPATH                   # Create SSH directory and keyring
touch ~/.ssh/authorized_keys            # Create authorized_keys file

# --- SSH permissions
chmod 700 ~/.ssh                        # Set permissions
chmod 700 $KEYRINGPATH                  # Set permissions
chmod 600 ~/.ssh/authorized_keys        # Set permissions

# --- Generate SSH keys
# --- Host
mkdir $KEYRINGPATH/$HOSTKEY             # Create SSH directory
chmod 700 $KEYRINGPATH/$HOSTKEY         # Set permissions
ssh-keygen -t ed25519 \
  -C "$HOSTKEY" \
  -f $KEYRINGPATH/$HOSTKEY/$HOSTKEY     # Generate SSH key
eval "$(ssh-agent -s)"                  # Start SSH agent
ssh-add $KEYRINGPATH/$HOSTKEY/$HOSTKEY  # Add SSH key to agent
cat $KEYRINGPATH/$HOSTKEY/$HOSTKEY.pub  # Display public key
# --- GitHub
mkdir $KEYRINGPATH/github               # Create SSH directory
chmod 700 $KEYRINGPATH/github           # Set permissions
ssh-keygen -t ed25519 \
  -C "$GITHUBKEY" \
  -f $KEYRINGPATH/github/github         # Generate SSH key
eval "$(ssh-agent -s)"                  # Start SSH agent
ssh-add $KEYRINGPATH/github/github      # Add SSH key to agent
cat $KEYRINGPATH/github/github.pub      # Display public key
