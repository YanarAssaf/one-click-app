#!/bin/bash

### VARIABLES ###
PRE_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 
VER="1.11.1"

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

systemctl disable firewalld --now
setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install epel-release >/dev/null
dnf -y -q install $PRE_PACK >/dev/null

cecho "Downloading and instaling node_exporter..." $boldyellow

#wget -q https://github.com/prometheus/node_exporter/releases/download/v1.4.0/node_exporter-1.11.1.linux-amd64.tar.gz >/dev/null
wget -q https://yanarit.com/node_exporter-$VER.linux-amd64.tar.gz >/dev/null

tar zxvf node_exporter-$VER.linux-amd64.tar.gz >/dev/null
sudo useradd --no-create-home --shell /sbin/nologin node_exporter
mv node_exporter-$VER.linux-amd64/node_exporter /usr/local/bin/
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter


cecho "Download & install has been completed" $boldgreen

cat <<EOF > /etc/systemd/system/node_exporter.service
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=node_exporter
Group=node_exporter
ExecStart=/usr/local/bin/node_exporter \
  --collector.systemd \
  --collector.processes
Restart=always
RestartSec=5
SyslogIdentifier=node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter.service --now
