#!/bin/bash

### VARIABLES ###
PRE_PACK="epel-release dnf-plugins-core"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 
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
dnf install -y -q $PRE_PACK >/dev/null
dnf install -y -q $EXT_PACK >/dev/null
cd /tmp

cecho "Downloading and installing Docker..." $boldyellow
sudo dnf -y -q remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine \
                  podman \
                  runc
				  
sudo dnf -y -q install dnf-plugins-core >/dev/null
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf -y -q install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
sudo systemctl enable --now docker

cecho "Download & install has been completed" $boldgreen
