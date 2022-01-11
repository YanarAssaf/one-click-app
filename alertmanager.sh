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


cecho "Downloading and installing Prometheus..." $boldyellow

useradd --no-create-home --shell /bin/false alertmanager
wget https://github.com/prometheus/alertmanager/releases/download/v0.23.0/alertmanager-0.23.0.linux-amd64.tar.gz >/dev/null
tar zxvf alertmanager-0.23.0.linux-amd64.tar.gz

mkdir -p /etc/alertmanager
mv alertmanager-0.23.0.linux-amd64/{alertmanager,amtool} /usr/local/bin/
mv alertmanager-0.23.0.linux-amd64/alertmanager.yml /etc/alertmanager
chown alertmanager:alertmanager /usr/local/bin/{alertmanager,amtool}
chown -R alertmanager:alertmanager /etc/alertmanager/

cecho "Download & install has been completed" $boldgreen

cat <<EOF > /etc/systemd/system/alertmanager.service
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
User=alertmanager
Group=alertmanager
Type=simple
WorkingDirectory=/etc/alertmanager/
ExecStart=/usr/local/bin/alertmanager \
    --config.file=/etc/alertmanager/alertmanager.yml
	
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl restart alertmanager
systemctl enable alertmanager

cat <<EOF > /etc/alertmanager/alertmanager.yml
global:
  smtp_from: 'no-reply'
  smtp_smarthost: 192.168.X.x:587
  smtp_auth_username: 'no-reply'
  smtp_auth_password: 'password'
  smtp_require_tls: false

route:
  group_by: ['alertname']
  receiver: 'email'

receivers:
- name: 'email'
  email_configs:
  - to: 'admin'
EOF

sed -i '4i \rule_files:\n  - rules.yml\n' /etc/prometheus/prometheus.yml
sed -i '7i \alerting:\n  alertmanagers:\n  - static_configs:\n    - targets:\n      - localhost:9093\n' /etc/prometheus/prometheus.yml
    
cecho "Example Rules" $boldgreen
cecho "https://awesome-prometheus-alerts.grep.to/rules.html#rule-redis-1-9"
