#!/bin/bash

### VARIABLES ###
PRE_PACK="yum-utils"
VER=""

# Setup Colours
black='\E[30;40m'
red='\E[31;40m'
green='\E[32;40m'
yellow='\E[33;40m'
blue='\E[34;40m'
magenta='\E[35;40m'
cyan='\E[36;40m'
white='\E[37;40m'

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
yum install -y -q $PRE_PACK >/dev/null


yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null
cecho "Installing Docker..." $boldyellow
yum -y -q install docker-ce docker-ce-cli containerd.io >/dev/null
systemctl daemon-reload && systemctl restart docker 
curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1
chmod +x /usr/local/bin/docker-compose

# Proxy
# echo "proxy=http://51.15.80.136:3128" >> /etc/yum.conf
# mkdir /etc/systemd/system/docker.service.d
# touch /etc/systemd/system/docker.service.d/http-proxy.conf
# echo "[Service]" >> /etc/systemd/system/docker.service.d/http-proxy.conf
# echo "Environment=\"HTTP_PROXY=http://51.15.80.136:3128/\"" >> /etc/systemd/system/docker.service.d/http-proxy.conf
