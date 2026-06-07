#!/bin/bash

### VARIABLES ###
PRE_PACK="epel-release"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion openssl yum-utils"
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

read -p "Enter install directory [/nexus]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/nexus}

# Clean trailing slashes if any
INSTALL_DIR=$(echo "$INSTALL_DIR" | sed 's:/*$::')

############################
# START DEPLOYMENT
############################

cecho "Creating storage directories..." $boldyellow
mkdir -p "$INSTALL_DIR/nexus-data"
mkdir -p "$INSTALL_DIR/npm/data"
mkdir -p "$INSTALL_DIR/npm/letsencrypt"

# Ensure proper permissions for the Nexus volume mount
chown -R 200:200 "$INSTALL_DIR/nexus-data"

cecho "Generating docker-compose.yml configuration..." $boldyellow

cat << EOF > "$INSTALL_DIR/docker-compose.yml"
version: '3.8'

networks:
  nexus_network:
    driver: bridge

services:
  nginx-proxy-manager:
    image: 'jc21/nginx-proxy-manager:latest'
    container_name: nginx-proxy-manager
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - '$INSTALL_DIR/npm/data:/data'
      - '$INSTALL_DIR/npm/letsencrypt:/etc/letsencrypt'
    networks:
      - nexus_network

  nexus:
    image: sonatype/nexus3:latest
    container_name: nexus-server
    restart: unless-stopped
    ports:
      - '8081:8081'
    volumes:
      - '$INSTALL_DIR/nexus-data:/nexus-data'
    networks:
      - nexus_network
EOF

cecho "Launching stack containers via Docker Compose..." $boldyellow
cd "$INSTALL_DIR"
docker compose up -d

if [ $? -eq 0 ]; then
    cecho "==========================================================" $boldgreen
    cecho " 🎉 Deployment Successful!" $boldgreen
    cecho "==========================================================" $boldgreen
    
    cecho "\n📌 Access Information:" $boldyellow
    echo "  • Nexus UI:     http://YOUR_SERVER_IP:8081"
    echo "  • Default User: admin"
    echo "  • Default Pass: docker exec -it nexus-server cat /nexus-data/admin.password"
    echo ""
    cecho "\n🔒 Steps to configure Let's Encrypt" $boldcyan
    echo "  1. Point your Nexus UI & Registry domains in DNS to this server IP"
    echo "     ↳ Log into the Nginx Proxy Manager Admin UI http://YOUR_SERVER_IP:81 "
    echo "  2. Add a Proxy Host for Nexus UI:"
    echo "     ↳ Domain Name: [Your Nexus Domain]"
    echo "     ↳ Forward Scheme: http" 
	echo "     ↳ Forward Host: nexus-server"
	echo "     ↳ Forward Port: 8080"
	echo "     ↳ Under 'SSL' tab: Request a new Let's Encrypt certificate."
    echo "  3. Add a Proxy Host for Docker Registry:"
    echo "     ↳ Domain Name: [Your Registry Domain]"
    echo "     ↳ Forward Scheme: http"
	echo "     ↳ Forward Host: nexus-server"
	echo "     ↳ Forward Port: [Your Nexus Docker HTTP Connector Port]"
	echo "     ↳ Under 'SSL' tab: Request a new Let's Encrypt certificate."
    
    echo ""
    cecho "==========================================================" $boldgreen
else
    cecho "❌ Deployment failed. Check docker system logs using 'docker compose logs'." $boldred
    exit 1
fi
