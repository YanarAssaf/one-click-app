#!/bin/bash

### VARIABLES ###
PRE_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 
VER="3.11.3"
#VER=$(curl -sI https://github.com/prometheus/prometheus/releases/latest | grep -i ^location | grep -o v[0-9.]* | sed s/^v//)

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

useradd --no-create-home --shell /bin/false prometheus
mkdir -p /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /var/lib/prometheus

cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install epel-release >/dev/null
dnf -y -q install $PRE_PACK >/dev/null

cecho "Downloading and installing Prometheus..." $boldyellow
#wget https://github.com/prometheus/prometheus/releases/download/v${VER}/prometheus-${VER}.linux-amd64.tar.gz >/dev/null
wget https://yanarit.com/prometheus-3.11.3.linux-amd64.tar.gz >/dev/null
tar xvf prometheus-${VER}.linux-amd64.tar.gz  >/dev/null
mv prometheus-${VER}.linux-amd64/{prometheus,promtool} /usr/local/bin/ 
chown prometheus:prometheus /usr/local/bin/{prometheus,promtool}

cecho "Download & install has been completed" $boldgreen

cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 60s
scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: "node_exporter"
    static_configs:
      - targets: ["localhost:9100"]
        labels:
          instance_name: "prometheus-server"
EOF

chown -R prometheus:prometheus /etc/prometheus ; chown prometheus:prometheus /var/lib/prometheus 


cat <<EOF > /etc/systemd/system/prometheus.service
[Unit]
Description=Prometheus 3 Monitoring System
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target
[Service]
Type=simple
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --storage.tsdb.retention.time=30d \
  --web.listen-address=0.0.0.0:9090 \
  --web.enable-lifecycle \
  --web.enable-otlp-receiver \
  --enable-feature=memory-snapshot-on-shutdown
Restart=always
RestartSec=5
SyslogIdentifier=prometheus
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus.service --now
