#!/bin/bash

### VARIABLES ###
PRE_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion"
EXT_PACK="" 
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

cecho "Installing Prerequisite Packages..." $boldyellow
dnf install -y -q epel-release >/dev/null
dnf install -y -q $EXT_PACK >/dev/null
dnf install -y -q $PRE_PACK >/dev/null

cat <<EOF > /etc/yum.repos.d/grafana.repo
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=0
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
EOF

cecho "Downloading and instaling Grafana..." $boldyellow
#dnf -y -q install $PRE_PACK >/dev/null
dnf -y -q install grafana >/dev/null
systemctl enable grafana-server --now
cecho "Download & install has been completed" $boldgreen
