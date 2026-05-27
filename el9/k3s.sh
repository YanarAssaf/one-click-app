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


# ==========================================
# CRITICAL HOSTNAME & HOSTS WARNING
# ==========================================
cecho "==========================================================" $boldred
cecho "               CRITICAL REQUIREMENT WARNING               " $boldred
cecho "==========================================================" $boldred
cecho "Before deploying K3s, you MUST ensure:" $boldwhite
cecho "1. Each node has a unique, permanent system hostname." $boldyellow
cecho "   Example: hostnamectl set-hostname master-01" $boldcyan
cecho "2. Your /etc/hosts file maps all node IPs to their hostnames." $boldyellow
cecho "   Example entries:" $boldcyan
echo "   10.10.0.35  master-01"
echo "   10.10.0.36  master-02"
echo "   10.10.0.37  worker-01"
cecho "==========================================================" $boldred
echo ""
read -p "Have you configured your hostnames and /etc/hosts file? (y/n): " CONFIRM

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    cecho "\nPlease configure your node network settings first. Exiting script." $boldyellow
    exit 0
fi

clear

systemctl disable firewalld --now
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install $PRE_PACK >/dev/null
dnf -y -q install $EXT_PACK >/dev/null

# ==========================================
# DISPLAY MENU
# ==========================================

echo ""
cecho "=========================================" $boldcyan
cecho "       K3S INSTALLATION MENU            " $boldcyan
cecho "=========================================" $boldcyan
cecho "1) Install Highly Available (HA) Initial Cluster Master" $boldwhite
cecho "2) Install Standalone Single Master" $boldwhite
cecho "3) Join Existing HA Cluster as an Additional Master" $boldwhite
cecho "4) Join Existing Cluster as Worker Agent" $boldwhite
echo ""
read -p "Please select an option [1-4]: " OPTION

# Validate option before asking for inputs
if [[ ! "$OPTION" =~ ^[1-4]$ ]]; then
    cecho "\nInvalid option selected! Exiting script." $boldred
    exit 1
fi

# ==========================================
# COLLECT USER INPUTS (OPTIMIZED & CENTRALIZED)
# ==========================================
echo ""
cecho "--- Configuration Inputs ---" $boldblue
read -p "Enter Secret Token to use: " YOUR_SECRET

# If option is 3 or 4, we also need the existing Master IP
if [ "$OPTION" -eq 3 ] || [ "$OPTION" -eq 4 ]; then
    read -p "Enter Existing Master IP Address: " MASTER_IP
fi

# ==========================================
# K3S INSTALLATION LOGIC
# ==========================================

case $OPTION in
    1)
        cecho "\nStarting K3s HA installation..." $boldgreen
        curl -sfL https://get.k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - server --cluster-init --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        ;;
    2)
        cecho "\nStarting K3s Standalone installation..." $boldgreen
        curl -sfL https://get.k3s.io | K3S_TOKEN=$YOUR_SECRET sh -
        ;;
    3)
        cecho "\nJoining as an additional Master..." $boldgreen
        curl -sfL https://get.k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - server --server https://$MASTER_IP:6443 --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        ;;
    4)
        cecho "\nJoining as a Worker Agent..." $boldgreen
		curl -sfL https://get.k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - agent --server https://$MASTER_IP:6443
        ;;
esac

# ==========================================
# POST-INSTALL CONFIGURATION
# ==========================================

# Configure kubectl bash auto-completion if kubectl exists or is installed
if command -v kubectl &> /dev/null; then
    cecho "\nConfiguring kubectl bash completion and shortcuts..." $boldyellow
    
    if ! grep -q "bash_completion" ~/.bashrc; then
        echo '[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion' >> ~/.bashrc
        echo 'source <(kubectl completion bash)' >> ~/.bashrc
        echo 'alias k=kubectl' >> ~/.bashrc
        echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
    fi
    
    cecho "Autocompletion configuration complete! Reloading session..." $boldgreen
fi

# AUTOMATICALLY RELOAD TERMINAL FOR USER
exec bash

#/usr/local/bin/k3s-uninstall.sh
#/usr/local/bin/k3s-agent-uninstall.sh
