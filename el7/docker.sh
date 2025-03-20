#!/bin/bash

### VARIABLES ###
EXT_PACK="wget vim net-tools htop mtr ntp rsync bash-completion bash-completion-extras" 
PRE_PACK="yum-utils device-mapper-persistent-data lvm2"

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

setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a
yum -y remove firewalld >/dev/null

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $EXT_PACK >/dev/null
yum install -y -q $PRE_PACK >/dev/null
cecho "Downloading and installing Docker..." $boldyellow
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null
cecho "Installing Docker..." $boldyellow
yum -y -q install docker-ce docker-ce-cli containerd.io >/dev/null
systemctl daemon-reload && systemctl restart docker 
curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >/dev/null 2>&1
chmod +x /usr/local/bin/docker-compose
cecho "Download & install has been completed\n" $boldgreen
