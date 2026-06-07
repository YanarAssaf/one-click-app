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

if ! command -v docker &> /dev/null; then
    echo "Error: Please install Docker first."
    exit 1
fi 

cecho "Installing Prerequisite Packages..." $boldyellow
dnf install -y -q $PRE_PACK >/dev/null
dnf install -y -q $EXT_PACK >/dev/null

############################
# USER INPUT SECTION
############################

read -p "Enter base domain (e.g. yanarit.com): " BASE_DOMAIN
read -p "Enter Nexus UI domain (e.g. nexus.yanarit.com): " NEXUS_DOMAIN
read -p "Enter Docker registry domain (e.g. repo.yanarit.com): " REPO_DOMAIN

read -p "Enter install directory [/nexus]: " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/nexus}

read -p "Company name: " COMPANY
read -p "Department: " DEPARTMENT
read -p "Country (2-letter code, e.g. SY, GB, US): " COUNTRY
read -p "State: " STATE
read -p "City: " CITY

COUNTRY=$(echo "$COUNTRY" | tr '[:lower:]' '[:upper:]')

if [[ ! "$COUNTRY" =~ ^[A-Z]{2}$ ]]; then
    cecho "ERROR: Country must be a 2-letter ISO code (e.g. SY, GB, US)." $boldred
    exit 1
fi

############################
# DEFAULT PORTS
############################

NEXUS_UI_PORT=8081
NEXUS_DOCKER_PORT=5000

############################
# START
############################

cecho "Creating directories..." $boldyellow

mkdir -p "$INSTALL_DIR/config/ssl"

############################
# SSL CERT GENERATION
############################

cecho "Generating SSL cert..." $boldyellow

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
  -keyout "$INSTALL_DIR/config/ssl/nexus.key" \
  -out "$INSTALL_DIR/config/ssl/nexus.crt" \
  -subj "/C=$COUNTRY/ST=$STATE/L=$CITY/O=$COMPANY/OU=$DEPARTMENT/CN=$BASE_DOMAIN" \
  -addext "subjectAltName=DNS:$BASE_DOMAIN,DNS:$NEXUS_DOMAIN,DNS:$REPO_DOMAIN"
  

############################
# DOCKER COMPOSE
############################

cat <<EOF > "$INSTALL_DIR/docker-compose.yaml"
services:
  nexus:
    image: sonatype/nexus3
    container_name: nexus
    ports:
      - "8081:8081"
      - "5000:5000"
      - "5001:5001"
    volumes:
      - nexus-data:/nexus-data
    restart: always

  proxy:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf
      - ./config/ssl/:/etc/nginx/ssl
    restart: always

volumes:
  nexus-data:
EOF

############################
# NGINX CONFIG
############################

cat <<EOF > "$INSTALL_DIR/config/nginx.conf"
worker_processes 1;

events {
  worker_connections 1024;
}

http {
    proxy_send_timeout 120;
    proxy_read_timeout 300;
    proxy_buffering off;
    proxy_request_buffering off;
    keepalive_timeout 5 5;
    tcp_nodelay on;

    server {
        listen 80;
        server_name $REPO_DOMAIN $NEXUS_DOMAIN;
        return 301 https://\$host\$request_uri;
    }

    server {
        listen 443 ssl;
        server_name $REPO_DOMAIN;

        ssl_certificate /etc/nginx/ssl/nexus.crt;
        ssl_certificate_key /etc/nginx/ssl/nexus.key;

        client_max_body_size 2G;

        location / {
            proxy_pass http://nexus:81;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port 443;
        }
    }

    server {
        listen 443 ssl;
        server_name $NEXUS_DOMAIN;

        ssl_certificate /etc/nginx/ssl/nexus.crt;
        ssl_certificate_key /etc/nginx/ssl/nexus.key;

        client_max_body_size 2G;

        location / {
            proxy_pass http://nexus:$NEXUS_UI_PORT;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
            proxy_set_header X-Forwarded-Host \$host;
            proxy_set_header X-Forwarded-Port 443;
        }
    }
}
EOF

############################
# RUN
############################

cecho "Starting Docker..." $boldgreen

cd "$INSTALL_DIR" || exit 1
docker compose up -d


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
    echo "  • Default Pass: docker exec -it nexus cat /nexus-data/admin.password"
    
    cecho "\n🌐 DIRECT ACCESS (HTTP):" $boldcyan
    echo "  1. Yum/Dnf clients:"
    echo "     ↳ baseurl=http://REPO_DOMAIN/repository/el10/"
    echo "     ↳ dnf install nginx --disablerepo='*' --enablerepo=yanarit-el10"
    echo "  2. Docker insecure-registries:"
    echo "     ↳ Port 5000 MUST be configured as the Nexus registry port."
    echo "     ↳ echo '{\"insecure-registries\":[\"<SERVER-IP>:5000\"]}' > /etc/docker/daemon.json"
    
    cecho "\n🔒 DIRECT ACCESS (HTTPS):" $boldcyan
    echo "  1. CA Certificate Deployment (AlmaLinux / RHEL):"
    echo "     ↳ rsync -avz \$INSTALL_DIR/config/ssl/nexus.crt client:/etc/pki/ca-trust/source/anchors/"
    echo "     ↳ update-ca-trust"
    echo "  2. Yum/DNF clients:"
    echo "     ↳ baseurl=https://REPO_DOMAIN/repository/el10/"
    echo "     ↳ dnf install nginx --disablerepo='*' --enablerepo=yanarit-el10"
    echo "  3. Docker repositories behind Nginx:"
    echo "     ↳ Port 81 MUST be configured or update Nginx conf file (Type HTTP)."
    
    echo ""
    cecho "==========================================================" $boldgreen
else
    cecho "❌ Deployment failed. Check docker system logs using 'docker compose logs'." $boldred
    exit 1
fi
