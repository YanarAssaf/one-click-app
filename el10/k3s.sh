#!/bin/bash

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script as root or using sudo."
    exit 1
fi

### VARIABLES ###
PRE_PACK="epel-release"
EXT_PACK="kernel-modules-extra nfs-utils tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 

# Setup Colors
boldred='\033[1;31m'
boldgreen='\033[1;32m'
boldyellow='\033[1;33m'
boldblue='\033[1;34m'
boldcyan='\033[1;36m'
boldwhite='\033[1;37m'
Reset='\033[0m'

cecho() {
    local message="$1"
    local color="$2"
    echo -e "${color}${message}${Reset}"
}

clear

# ==========================================
# STAGE SELECTION MENU
# ==========================================
cecho "=========================================" "$boldcyan"
cecho "       K3S DEPLOYMENT WORKFLOW           " "$boldcyan"
cecho "=========================================" "$boldcyan"
cecho "1) Stage 1: Prepare Server (OS Config & Prerequisites)" "$boldwhite"
cecho "2) Stage 2: Install / Join K3s Cluster (Post-Reboot)" "$boldwhite"
echo ""
read -r -p "Please select a workflow stage [1-2]: " STAGE

if [[ ! "$STAGE" =~ ^[1-2]$ ]]; then
    cecho "\nInvalid stage selected! Exiting script." "$boldred"
    exit 1
fi

clear

# ==========================================
# STAGE 1: PREPARE SERVER
# ==========================================
if [ "$STAGE" -eq 1 ]; then
    # CRITICAL HOSTNAME & HOSTS WARNING
    cecho "==========================================================" "$boldred"
    cecho "               CRITICAL REQUIREMENT WARNING               " "$boldred"
    cecho "==========================================================" "$boldred"
    cecho "Before preparing this node, you MUST ensure:" "$boldwhite"
    cecho "1. Each node has a unique, permanent system hostname." "$boldyellow"
    cecho "   Example: hostnamectl set-hostname master-01" "$boldcyan"
    cecho "2. Your /etc/hosts file maps all node IPs to their hostnames." "$boldyellow"
    cecho "   Example entries:" "$boldcyan"
    echo "   10.10.0.35  master-01"
    echo "   10.10.0.36  master-02"
    echo "   10.10.0.37  worker-01"
    cecho "==========================================================" "$boldred"
    echo ""
    read -r -p "Have you configured your hostnames and /etc/hosts file? (y/n): " CONFIRM

    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        cecho "\nPlease configure your node network settings first. Exiting script." "$boldyellow"
        exit 0
    fi

    clear

    cecho "Optimizing OS Firewall and Virtual Memory configurations..." "$boldyellow"
    systemctl disable firewalld --now &>/dev/null || true

    # Turn off swap safely for Kubernetes performance
    swapoff -a
    sed -i '/swap/s/^/#/' /etc/fstab

    cecho "Installing Prerequisite Packages (this may take a moment)..." "$boldyellow"
    dnf -y -q install $PRE_PACK >/dev/null
    dnf -y -q install $EXT_PACK >/dev/null

    echo ""
    cecho "==========================================================" "$boldgreen"
    cecho "       STAGE 1 COMPLETE: SERVER PREPARED SUCCESSFULLY     " "$boldgreen"
    cecho "==========================================================" "$boldgreen"
    cecho "You MUST now reboot the server to apply kernel modules and configs." "$boldyellow"
    cecho "After rebooting, execute this script again and select Option 2." "$boldcyan"
    echo ""
    read -r -p "Would you like to reboot the server now? (y/n): " REBOOT_NOW
    if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
        cecho "Rebooting server..." "$boldred"
        reboot
    else
        cecho "Exiting script. Please manually reboot before moving to Stage 2." "$boldwhite"
    fi
    exit 0
fi

# ==========================================
# STAGE 2: K3S INSTALLATION MENU & CONFIG
# ==========================================
# This section executes cleanly if Stage 2 is chosen directly after a system reboot

echo ""
cecho "=========================================" "$boldcyan"
cecho "       K3S INSTALLATION CLUSTER MENU    " "$boldcyan"
cecho "=========================================" "$boldcyan"
cecho "1) Install Highly Available (HA) Initial Cluster Master" "$boldwhite"
cecho "2) Install Standalone Single Master" "$boldwhite"
cecho "3) Join Existing HA Cluster as an Additional Master" "$boldwhite"
cecho "4) Join Existing Cluster as Worker Agent" "$boldwhite"
echo ""
read -r -p "Please select a cluster setup option [1-4]: " OPTION

if [[ ! "$OPTION" =~ ^[1-4]$ ]]; then
    cecho "\nInvalid option selected! Exiting script." "$boldred"
    exit 1
fi

# ==========================================
# COLLECT USER INPUTS
# ==========================================
echo ""
cecho "--- Configuration Inputs ---" "$boldblue"
read -r -p "Enter Secret Token to use: " YOUR_SECRET

if [ -z "$YOUR_SECRET" ]; then
    cecho "Secret Token cannot be empty. Exiting script." "$boldred"
    exit 1
fi

# Additional inputs for Option 1
if [ "$OPTION" -eq 1 ]; then
    read -r -p "Deploy with an external load balancer? (y/n): " USE_LB
    if [[ "$USE_LB" =~ ^[Yy]$ ]]; then
        read -r -p "Enter TLS SAN IP / Load Balancer IP: " TLS_IP
    fi
fi

# Additional inputs for Option 3
if [ "$OPTION" -eq 3 ]; then
    read -r -p "Deploy with an external load balancer? (y/n): " USE_LB
    if [[ "$USE_LB" =~ ^[Yy]$ ]]; then
        read -r -p "Enter TLS SAN IP / Load Balancer IP: " TLS_IP
    fi
    read -r -p "Enter Existing Master IP Address: " MASTER_IP
fi

# Additional inputs for Option 4
if [ "$OPTION" -eq 4 ]; then
    read -r -p "Enter Existing Master IP Address: " MASTER_IP
fi

# ==========================================
# K3S INSTALLATION LOGIC
# ==========================================
case $OPTION in
    1)
        if [[ "$USE_LB" =~ ^[Yy]$ ]]; then
            cecho "\nStarting K3s HA initialization with External Load Balancer ($TLS_IP)..." "$boldgreen"
            curl -sfL https://k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - server --cluster-init --tls-san="$TLS_IP" --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        else
            cecho "\nStarting K3s HA initialization..." "$boldgreen"
            curl -sfL https://k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - server --cluster-init --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        fi
        ;;
    2)
        cecho "\nStarting K3s Standalone installation..." "$boldgreen"
        curl -sfL https://k3s.io | K3S_TOKEN=$YOUR_SECRET sh -
        ;;
    3)
        if [[ "$USE_LB" =~ ^[Yy]$ ]]; then
            cecho "\nJoining as an additional Master via External Load Balancer ($TLS_IP)..." "$boldgreen"
            curl -sfL https://k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - server --server "https://${TLS_IP}:6443" --tls-san="$TLS_IP" --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        else
            cecho "\nJoining as an additional Master connecting to $MASTER_IP..." "$boldgreen"
            curl -sfL https://k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - server --server "https://${MASTER_IP}:6443" --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'
        fi
        ;;
    4)
        cecho "\nJoining as a Worker Agent connecting to $MASTER_IP..." "$boldgreen"
        curl -sfL https://k3s.io | K3S_TOKEN=$YOUR_SECRET sh -s - agent --server "https://${MASTER_IP}:6443"
        ;;
esac

# ==========================================
# POST-INSTALL CONFIGURATION
# ==========================================
if [ -f /usr/local/bin/kubectl ] || [ -f /usr/bin/kubectl ] || command -v kubectl &> /dev/null; then
    cecho "\nConfiguring kubectl bash completion and shortcuts..." "$boldyellow"
    
    TARGET_HOME=$(eval echo "~${SUDO_USER:-root}")
    BASHRC_PATH="$TARGET_HOME/.bashrc"

    if ! grep -q "kubectl completion" "$BASHRC_PATH"; then
        echo '[[ -r /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion' >> "$BASHRC_PATH"
        echo 'source <(kubectl completion bash)' >> "$BASHRC_PATH"
        echo 'alias k=kubectl' >> "$BASHRC_PATH"
        echo 'complete -o default -F __start_kubectl k' >> "$BASHRC_PATH"
        
        if [ -n "$SUDO_USER" ]; then
            chown "$SUDO_USER":"$SUDO_USER" "$BASHRC_PATH"
        fi
    fi
    cecho "Autocompletion configuration complete!" "$boldgreen"
fi

echo ""
cecho "Deployment script completed successfully!" "$boldgreen"
echo "Press Enter to start a fresh shell session or close this terminal window."
read -r

if [ -n "$SUDO_USER" ]; then
    exec su - "$SUDO_USER"
else
    exec bash
fi
