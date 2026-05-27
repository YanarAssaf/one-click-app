#!/bin/bash

### VARIABLES ###
PRE_PACK="epel-release"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 
VER="0.30.1"

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
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install $PRE_PACK >/dev/null
dnf -y -q install $EXT_PACK >/dev/null

cecho "Downloading and instaling snmp_exporter..." $boldyellow
cd /tmp
#wget https://github.com/prometheus/snmp_exporter/releases/download/v0.21.0/snmp_exporter-0.21.0.linux-amd64.tar.gz
wget -q https://yanarit.com/snmp_exporter-$VER.linux-amd64.tar.gz
tar zxvf snmp_exporter-$VER.linux-amd64.tar.gz >/dev/null

cp snmp_exporter-$VER.linux-amd64/snmp_exporter /usr/local/bin/snmp_exporter
cp snmp_exporter-$VER.linux-amd64/snmp.yml /etc/prometheus/snmp.yml
cecho "Download & install has been completed" $boldgreen

cat <<EOF > /etc/systemd/system/snmp-exporter.service
[Unit]
Description=Prometheus SNMP Exporter Service
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/snmp_exporter --config.file=/etc/prometheus/snmp.yml

[Install]
WantedBy=multi-user.target
EOF

cecho "Add snmp job to your prometheus conf file" $boldgreen
echo ""

cecho "
  - job_name: 'snmp'
    scrape_timeout: 1m
    static_configs:
      - targets:
        - switch.local # SNMP device.
    metrics_path: /snmp
    params:
      module: [if_mib]
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9116 " $boldgreen


sed -i '7795i \ \ version: 2\n  auth:\n    community: '$COMMUNITY'' /etc/prometheus/snmp.yml
systemctl enable --now snmp-exporter.service
