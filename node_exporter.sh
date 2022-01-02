#!/bin/bash

### VARIABLES ###
PRE_PACK="" 
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


cecho "Downloading and instaling node_exporter..." $boldyellow

wget -q https://github.com/prometheus/node_exporter/releases/download/v1.3.1/node_exporter-1.3.1.linux-amd64.tar.gz >/dev/null

tar zxvf node_exporter-1.3.1.linux-amd64.tar.gz >/dev/null
useradd -rs /bin/false nodeusr
mv node_exporter-1.3.1.linux-amd64/node_exporter /usr/local/bin/

cecho "Download & install has been completed" $boldgreen

cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=nodeusr
Group=nodeusr
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter.service
