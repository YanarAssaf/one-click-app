#!/bin/bash
###Ubuntu22
##Nexus

EXT_PACK="" 
PRE_PACK=""

boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'

Reset="tput sgr0"

cecho() {
    message=$1
    color=$2
    echo -e "$color$message"
    $Reset
    return
}
clear

cecho "Installing Docker..." $boldyellow
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
apt update -y 
apt-cache policy docker-ce -y 
sudo apt install docker-ce docker-compose -y 

cecho "Creating Dir..." $boldyellow
mkdir /nexus && cd /nexus && \
mkdir -p config/ssl
cd config/ssl

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /nexus/config/ssl/nexus.key -out /nexus/config/ssl/nexus.crt \
   -subj "/C=US/ST=California/L=San Francisco/O=Your Company/OU=Your Department/CN=app.sy" \
   -addext "subjectAltName=DNS:app.sy,DNS:nexus.app.sy,DNS:docker.app.sy"
   
cd ..

cat <<EOF > /nexus/docker-compose.yaml
services:
  nexus:
    image: "sonatype/nexus3"
    volumes:
      - "nexus-data:/nexus-data"
    restart: always
  proxy:
    image: "nginx:alpine"
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

cat <<EOF > /nexus/config/nginx.conf
worker_processes 1;

events {
  worker_connections 1024;
}

http {
    proxy_send_timeout 120;
    proxy_read_timeout 300;
    proxy_buffering    off;
    proxy_request_buffering off;
    keepalive_timeout  5 5;
    tcp_nodelay        on;

    server {
        listen 80;
        server_name docker.app.sy;
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

#Registry Docker
    server {
        listen 443 ssl;
        server_name  docker.app.sy;
        ssl_certificate /etc/nginx/ssl/nexus.crt;
        ssl_certificate_key /etc/nginx/ssl/nexus.key;
        client_max_body_size 2G;
        # optimize downloading files larger than 1G - refer to nginx doc before adjusting
        #proxy_max_temp_file_size 2G;
            location / {
            proxy_pass http://nexus:81;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto "https";
        }

    }
	
#Web Nexus
server {
        listen 443 ssl;
        server_name  nexus.app.sy;
        ssl_certificate /etc/nginx/ssl/nexus.crt;
        ssl_certificate_key /etc/nginx/ssl/nexus.key;
        client_max_body_size 2G;
        # optimize downloading files larger than 1G - refer to nginx doc before adjusting
        #proxy_max_temp_file_size 2G;
            location / {
            proxy_pass http://nexus:8081;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto "https";
        }

    }

}
EOF


cecho "Run Docker compose " $boldgreen
docker compose up -d

#/usr/local/share/ca-certificates
#sudo update-ca-certificates

exit 0
