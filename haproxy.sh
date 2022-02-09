#!/bin/bash

### VARIABLES ###
EXT_PACK="wget vim net-tools htop mtr ntp rsync bash-completion bash-completion-extras iptables-services" 
PRE_PACK="make gcc wget systemd-devel"
VER="2.4.12"

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

yum remove -y -q firewalld >/dev/null 
setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $EXT_PACK >/dev/null
yum install -y -q $PRE_PACK >/dev/null
cd /tmp

cecho "Downloading and installing HAProxy..." $boldyellow
wget -q https://www.haproxy.org/download/2.4/src/haproxy-$VER.tar.gz
tar xzf haproxy-$VER.tar.gz 
cd /tmp/haproxy-$VER

make -j $(nproc) TARGET=linux-glibc CPU=x86_64 USE_SYSTEMD=1 >/dev/null 2>&1

if [ $? -eq 0 ]; then
    make install >/dev/null 2>&1
else
    cecho "Installation Failed" $boldred
    exit 1
fi

cecho "Download & install has been completed" $boldgreen

useradd -s /usr/sbin/nologin -r haproxy
ln -s /usr/local/sbin/haproxy /usr/sbin/haproxy
cp /tmp/haproxy-$VER/admin/systemd/haproxy.service.in /usr/lib/systemd/system
mkdir -p /etc/haproxy
mkdir -p /var/lib/haproxy   
touch /var/lib/haproxy/stats 

$(printf "global\n\tdaemon\n\tmaxconn 524252\n\tulimit-n 1048563\n\tnbproc 15\n\ndefaults\n\ttimeout connect 5000ms\n\ttimeout client 50000ms\n\ttimeout server 50000ms\n\nlisten proxys\n\tmode tcp\n\tlog global\n\tbind :80\n\tmaxconn 524252\n\t#balance roundrobin\n\tbalance source\n\tbind-process all\n\toption http-keep-alive\n\toption nolinger\n\toption redispatch\n\tsource 0.0.0.0 usesrc clientip\n\tserver cache1 192.168.100.1:3129 check port 3129 inter 2000 fall 3\n\toption tcp-smart-accept\n\toption tcp-smart-connect\n\nlisten stats\n\tbind :8888\n\tmode http\n\tstats enable\n\tstats refresh 30s\n\tstats show-node\n\tstats auth admin:password\n\tstats uri  /" >/etc/haproxy/haproxy.cfg)

systemctl daemon-reload
systemctl enable haproxy

exit 0
