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

############################
# download offline packages helper
############################
cat << 'EOF' > "$INSTALL_DIR/download-upload-rpms.sh"
#!/bin/bash

# ---------------------------
# Dynamic Configuration Input
# ---------------------------
# Input for Nexus URL (Press Enter for default)
read -p "Enter Nexus URL [http://10.10.0]: " NEXUS_URL
NEXUS_URL="${NEXUS_URL:-http://10.10.0}"

# Input for Username (Press Enter for default)
read -p "Enter Nexus Username [admin]: " NEXUS_USER
NEXUS_USER="${NEXUS_USER:-admin}"

# Input for Password (Hidden while typing. Type your exact password, even with $)
read -s -p "Enter Nexus Password: " NEXUS_PASS
echo "" # Prints a new line after password entry

# Input for Packages (Mandatory input)
while true; do
    read -p "Enter packages to download (separated by space): " PACKAGES
    # Check if the user entered anything
    if [ -n "$PACKAGES" ]; then
        break
    else
        echo "Error: You must enter at least one package name."
    fi
done

# ---------------------------
# Temporary download directory
# ---------------------------
TEMP_DIR="/tmp/webserver_rpms"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR" || exit 1

# ---------------------------
# Download packages and dependencies
# ---------------------------
echo "Downloading packages: $PACKAGES ..."
for pkg in $PACKAGES; do
    yumdownloader --resolve "$pkg"
done

# ---------------------------
# Upload RPMs to Nexus
# ---------------------------
echo "Uploading RPMs to Nexus..."
for rpm in *.rpm; do
    # Check if files actually exist to avoid loop errors
    [ -e "$rpm" ] || continue
    
    echo "Uploading $rpm ..."
    
    # Double quotes around variables ensure '$' inside the password is read literally
    curl -f -u "${NEXUS_USER}:${NEXUS_PASS}" \
         --upload-file "$rpm" \
         "${NEXUS_URL}${rpm}"

    if [ $? -eq 0 ]; then
        echo "SUCCESS: $rpm"
    else
        echo "FAILED: $rpm"
    fi
done

echo "All uploads completed."

EOF


cat <<EOF

=========================================================================
NEXUS DEPLOYMENT NOTES
=========================================================================

DIRECT ACCESS (HTTP)
--------------------

Nexus UI:
  http://<SERVER-IP>:8081

Use direct HTTP access for repositories that do not require the Nginx
reverse proxy, such as Yum, Apt, Raw, Maven, NPM and other standard
repository types.

Examples:
create repo file /etc/yum.repos.d/yanarit.repo
[yanarit]
name=Yanarit Nexus Repo
baseurl=http://NEXUS_DOMAIN:8081/repository/el10/
enabled=1
gpgcheck=0

Docker repositories over HTTP:
  <SERVER-IP>:5000
  <SERVER-IP>:5001

Docker clients may use the direct Nexus ports if insecure registries are
allowed in the Docker daemon configuration.

echo '{"insecure-registries":["<SERVER-IP>:5000"]}' > /etc/docker/daemon.json


HTTPS ACCESS (RECOMMENDED)
--------------------------

Nexus UI:
  https://$NEXUS_DOMAIN

Docker Registry:
  https://$REPO_DOMAIN

The HTTPS endpoints are published through Nginx using the generated SSL
certificate.


IMPORTANT
---------

The generated certificate is a private CA/self-signed certificate.

Before using HTTPS endpoints, import the generated CA certificate on all
client systems that will access Nexus.

Examples:
  Yum/DNF clients
  Docker hosts
  Linux servers
  Windows servers
  Workstations
  dnf install nginx --disablerepo='*' --enablerepo=yanarit-el10

create repo file /etc/yum.repos.d/yanarit.repo
[yanarit]
name=Yanarit Nexus Repo
baseurl=https://NEXUS_DOMAIN/repository/el10/
enabled=1
gpgcheck=0

DOCKER CONFIGURATION
--------------------

For Docker repositories behind Nginx:

  Registry URL:
    https://$REPO_DOMAIN

  Example Nexus Docker Connector:

    Type : HTTP
    Port : 81 MUST be configured as this port or update nginx conf file 

Nginx terminates SSL and forwards traffic to the Nexus HTTP connector.


EXAMPLES
--------

Yum Repository:
  https://$NEXUS_DOMAIN/repository/yum/

Docker Login:
  docker login $REPO_DOMAIN

Docker Push:
  docker push $REPO_DOMAIN/myimage:latest

Docker Pull:
  docker pull $REPO_DOMAIN/myimage:latest

CA CERTIFICATE DEPLOYMENT (ALMALINUX / RHEL)
--------------------------------------------
rsync -avz $INSTALL_DIR/config/ssl/nexus.crt \
      root@client:/etc/pki/ca-trust/source/anchors/
	  
On each client, update the trusted CA store:

  update-ca-trust

=========================================================================

EOF

cecho "docker exec -it nexus cat /nexus-data/admin.password" $boldgreen 
cecho "Done!" $boldgreen

exit 0
