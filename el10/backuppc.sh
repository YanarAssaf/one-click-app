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

cecho() {
    message=$1
    color=$2
    echo -e "$color$message"
    tput sgr0
    return
}

clear

# Verify Docker dependency
if ! command -v docker &> /dev/null; then
    cecho "Error: Please install Docker first." $boldred
    exit 1
fi 

# Verify Docker Compose dependency
if ! docker compose version &> /dev/null; then
    cecho "Error: 'docker compose' plugin is required. Please install it first." $boldred
    exit 1
fi

cecho "Installing Prerequisite Packages..." $boldyellow
dnf install -y -q $PRE_PACK >/dev/null
dnf install -y -q $EXT_PACK >/dev/null

############################
# USER INPUT SECTION
############################

read -p "Enter install directory [/backuppc]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/backuppc}

# Clean trailing slashes if any
INSTALL_DIR=$(echo "$INSTALL_DIR" | sed 's:/*$::')

mkdir -p "$INSTALL_DIR"

############################
# START DEPLOYMENT
############################

cecho "Generating docker-compose.yml configuration..." $boldyellow

cat << EOF > "$INSTALL_DIR/docker-compose.yml"
services:
  backuppc:
    image: 'adferrand/backuppc'
    container_name: backuppc
    restart: unless-stopped
    ports:
      - '8080:8080'
    volumes:
      - '$INSTALL_DIR/etc:/etc/backuppc'
      - '$INSTALL_DIR/home:/home/backuppc'
      - '$INSTALL_DIR/data:/data/backuppc'
      - '/etc/localtime:/etc/localtime:rp'

EOF

cecho "Launching stack containers via Docker Compose..." $boldyellow
cd "$INSTALL_DIR"
docker compose up -d

if [ $? -eq 0 ]; then
    cecho "==========================================================" $boldgreen
    cecho " Deployment Successful!" $boldgreen
    cecho "==========================================================" $boldgreen
    echo "BackupPC UI: http://YOUR_SERVER_IP:8080"
    echo "Default User: backuppc"
    echo "Default Pass: password"
    echo ""
    cecho "==========================================================" $boldgreen
else
    cecho "Deployment failed. Check docker system logs using 'docker compose logs'." $boldred
    exit 1
fi
