#!/bin/bash

### VARIABLES ###
PRE_PACK="epel-release"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 
VER=""

# Setup Colours
boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'
boldmagenta='\E[1;35;40m'
boldcyan='\E[1;36;40m'
boldwhite='\E[1;37;40m'

Reset="tput sgr0"

cecho() {
    message=$1
    color=$2
    echo -e "$color$message"
    $Reset
    return
}
clear

# Interactive User Menu
cecho "========================================" $boldcyan
cecho "      K3s Installation Setup" $boldcyan
cecho "========================================" $boldcyan
cecho "1) Install Highly Available (HA) Cluster Master" $boldwhite
cecho "2) Install Standalone Single Master" $boldwhite
cecho "========================================" $boldcyan
read -p "Enter your choice [1 or 2]: " CHOICE

# Validate setup mode input
if [[ "$CHOICE" != "1" && "$CHOICE" != "2" ]]; then
    cecho "Invalid option. Exiting script." $boldred
    exit 1
fi

echo ""
cecho "========================================" $boldcyan
cecho "      K3s Cluster Token Setup" $boldcyan
cecho "========================================" $boldcyan
read -p "Enter custom K3s Token (Leave blank to auto-generate): " USER_TOKEN

# If the user left it blank, generate a random token
if [ -z "$USER_TOKEN" ]; then
    USER_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
    cecho "Generated Auto Token: $USER_TOKEN" $boldmagenta
    cecho "--> SAVE THIS TOKEN! You need it to join other nodes." $boldmagenta
fi

echo ""
cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install $PRE_PACK >/dev/null
dnf -y -q install $EXT_PACK >/dev/null

cecho "Configure Master Server..." $boldyellow

case $CHOICE in
    1)
        cecho "Starting High Availability (HA) Installation..." $boldgreen
        curl -sfL https://k3s.io | K3S_TOKEN="$USER_TOKEN" sh -s - server \
            --cluster-init \
            --disable traefik \
            --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        ;;
    2)
        cecho "Starting Standalone Single Master Installation..." $boldgreen
        curl -sfL https://k3s.io | K3S_TOKEN="$USER_TOKEN" sh -s - server \
            --disable traefik
        ;;
esac

echo ""
cecho "========================================" $boldgreen
cecho " K3s installation command executed!" $boldgreen
cecho " Use Token: $USER_TOKEN" $boldyellow
cecho "========================================" $boldgreen

cecho "Download & install has been completed" $boldgreen
