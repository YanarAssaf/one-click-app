#!/bin/bash

EXT_PACK="wget vim net-tools htop mtr ntp rsync bash-completion bash-completion-extras" 
PRE_PACK="yum-utils"

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

systemctl stop firewalld ; systemctl disable firewalld
setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $EXT_PACK >/dev/null
yum install -y -q $PRE_PACK >/dev/null

$(printf "[nginx-stable]\nname=nginx stable repo\nbaseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/\ngpgcheck=1\nenabled=1\ngpgkey=https://nginx.org/keys/nginx_signing.key\nmodule_hotfixes=true" >/etc/yum.repos.d/nginx.repo)
cecho "Installing Nginx..." $boldyellow
yum -y install nginx >/dev/null 2>&1
cecho "Install has been completed" $boldgreen

exit 0
