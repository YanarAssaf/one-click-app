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
cecho "1) Install Highly Available (HA) Initial Cluster Master" $boldwhite
cecho "2) Install Standalone Single Master" $boldwhite
cecho "3) Join Existing HA Cluster as an Additional Master" $boldwhite
cecho "4) Join Existing Cluster as Worker Agent" $boldwhite
cecho "========================================" $boldcyan
read -p "Enter your choice [1, 2, 3, or 4]: " CHOICE

# Validate setup mode input
if [[ "$CHOICE" != "1" && "$CHOICE" != "2" && "$CHOICE" != "3" && "$CHOICE" != "4" ]]; then
    cecho "Invalid option. Exiting script." $boldred
    exit 1
fi

echo ""
cecho "========================================" $boldcyan
cecho "      K3s Cluster Token Setup" $boldcyan
cecho "========================================" $boldcyan

# Options 3 and 4 require entering the exact pre-existing cluster token
if [[ "$CHOICE" == "3" || "$CHOICE" == "4" ]]; then
    read -p "Enter your existing K3s Cluster Token: " USER_TOKEN
    while [ -z "$USER_TOKEN" ]; do
        cecho "Token cannot be blank for joining a cluster!" $boldred
        read -p "Enter your existing K3s Cluster Token: " USER_TOKEN
    done
else
    # Options 1 and 2 allow auto-generation if left blank
    read -p "Enter custom K3s Token (Leave blank to auto-generate): " USER_TOKEN
    if [ -z "$USER_TOKEN" ]; then
        USER_TOKEN=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 32)
        cecho "Generated Auto Token: $USER_TOKEN" $boldmagenta
        cecho "--> SAVE THIS TOKEN! You need it to join other nodes." $boldmagenta
    fi
fi

# IP Configuration Variable Setup
echo ""
cecho "========================================" $boldcyan
cecho "      IP Address Configuration" $boldcyan
cecho "========================================" $boldcyan

# Options 3 and 4 prompt for the target remote master IP
if [[ "$CHOICE" == "3" || "$CHOICE" == "4" ]]; then
    read -p "Enter Target Master Server IP (e.g., 172.20.20.61): " NODE_IP
    while [ -z "$NODE_IP" ]; do
        cecho "Master Server IP cannot be blank!" $boldred
        read -p "Enter Target Master Server IP: " NODE_IP
    done
else
    # Automatically grab this server's primary local IP address for Master initial setups
    NODE_IP=$(hostname -I | awk '{print $1}')
    cecho "Detected local Master IP: $NODE_IP" $boldgreen
fi

echo ""
cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install $PRE_PACK >/dev/null
dnf -y -q install $EXT_PACK >/dev/null

cecho "Configure K3s Service..." $boldyellow

if [ "$CHOICE" == "1" ]; then
    cecho "Starting High Availability (HA) Initial Installation..." $boldgreen
    curl -sfL https://get.k3s.io | K3S_TOKEN="$USER_TOKEN" sh -s - server \
        --cluster-init \
        --disable traefik \
        --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
elif [ "$CHOICE" == "2" ]; then
    cecho "Starting Standalone Single Master Installation..." $boldgreen
    curl -sfL https://get.k3s.io | K3S_TOKEN="$USER_TOKEN" sh -s - server \
        --disable traefik
elif [ "$CHOICE" == "3" ]; then
    cecho "Joining Cluster as an Additional HA Master Node..." $boldgreen
    curl -sfL https://get.k3s.io | K3S_TOKEN="$USER_TOKEN" sh -s - server \
        --server "https://${NODE_IP}:6443" \
        --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
else
    cecho "Joining Cluster as Worker Agent..." $boldgreen
    curl -sfL https://get.k3s.io | K3S_TOKEN="$USER_TOKEN" sh -s - agent \
        --server "https://${NODE_IP}:6443"
fi

echo ""
cecho "========================================" $boldgreen
cecho " K3s installation command executed!" $boldgreen
cecho " Use Token: $USER_TOKEN" $boldyellow
cecho " Target IP used: $NODE_IP" $boldyellow
cecho "========================================" $boldgreen


cecho "Download & install has been completed" $boldgreen
