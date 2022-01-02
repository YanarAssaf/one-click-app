#!/bin/bash

### VARIABLES ###
PRE_PACK="wget vim htop mtr ntp bash-completion" 
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

systemctl stop firewalld && systemctl disable firewalld
setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

useradd --no-create-home --shell /bin/false prometheus
mkdir /etc/prometheus ; mkdir /var/lib/prometheus

cecho "Installing Prerequisite Packages..." $boldyellow
yum -y -q install epel-release >/dev/null
yum -y -q install $PRE_PACK >/dev/null

cecho "Downloading and installing Prometheus..." $boldyellow
wget https://github.com/prometheus/prometheus/releases/download/v2.32.1/prometheus-2.32.1.linux-amd64.tar.gz >/dev/null
tar -xvzf prometheus-2.32.1.linux-amd64.tar.gz >/dev/null

cp prometheus-2.32.1.linux-amd64/prometheus /usr/local/bin/ ; cp prometheus-2.32.1.linux-amd64/promtool /usr/local/bin/
cp -r prometheus-2.32.1.linux-amd64/consoles /etc/prometheus; cp -r prometheus-2.32.1.linux-amd64/console_libraries /etc/prometheus
cecho "Download & install has been completed" $boldgreen

cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'node'
    scrape_interval: 5s
    static_configs:
      - targets: ['localhost:9090']
EOF

chown -R prometheus:prometheus /etc/prometheus ; chown prometheus:prometheus /var/lib/prometheus 
chown prometheus:prometheus /usr/local/bin/prometheus; chown prometheus:prometheus /usr/local/bin/promtool

cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \
--config.file /etc/prometheus/prometheus.yml \
--storage.tsdb.path /var/lib/prometheus/ \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--storage.tsdb.retention.time=1y

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus.service
