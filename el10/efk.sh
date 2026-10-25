#!/bin/bash

PRE_PACK="epel-release"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 


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

systemctl disable firewalld --now
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

cecho "Installing Prerequisite Packages..." $boldyellow
dnf -y -q install $PRE_PACK >/dev/null
dnf -y -q install $EXT_PACK >/dev/null

cat >> /etc/sysctl.conf <<'EOF'
vm.max_map_count=1048576
EOF

sysctl --system

rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

cat > /etc/yum.repos.d/elasticsearch.repo <<'EOF'
[elasticsearch]
name=Elasticsearch 9.x
baseurl=https://artifacts.elastic.co/packages/9.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=0
type=rpm-md
EOF

cat > /etc/yum.repos.d/kibana.repo <<'EOF'
[kibana-9.x]
name=Kibana repository for 9.x packages
baseurl=https://artifacts.elastic.co/packages/9.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

cecho "Installing elasticsearch..." $boldyellow
dnf -y install --enablerepo=elasticsearch elasticsearch

cp -a /etc/elasticsearch/elasticsearch.yml \
  "/etc/elasticsearch/elasticsearch.yml.bak.$(date +%Y%m%d-%H%M%S)"
  
sed -i -E \
'/^[[:space:]]*(discovery\.seed_hosts|cluster\.initial_master_nodes|discovery\.type)[[:space:]]*:/s/^/# disabled for single-node: /' \
/etc/elasticsearch/elasticsearch.yml

echo 'discovery.type: single-node' >> /etc/elasticsearch/elasticsearch.yml

systemctl daemon-reload
systemctl enable elasticsearch --now

cecho "Installing kibana..." $boldyellow
dnf install -y -q kibana-9.5.5
systemctl daemon-reload
systemctl enable kibana 

read -rp "Enter the Kibana server IP: " SERVER_IP
sudo sed -i.bak "s|^#server.host: \"localhost\"|server.host: \"$SERVER_IP\"|" /etc/kibana/kibana.yml

systemctl restart kibana

#Gen token and otp
/usr/share/elasticsearch/bin/elasticsearch-create-enrollment-token -s kibana
sleep 30
/usr/share/kibana/bin/kibana-verification-code

#/usr/share/elasticsearch/bin/elasticsearch-reset-password -u elastic
#curl --cacert /etc/elasticsearch/certs/http_ca.crt -u elastic https://localhost:9200

cecho "Install has been completed" $boldgreen

exit 0
