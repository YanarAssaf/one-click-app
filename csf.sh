#!/bin/bash

### VARIABLES ###
EXT_PACK="wget vim net-tools htop mtr ntp rsync bash-completion bash-completion-extras"
PRE_PACK="iptables-services perl-libwww-perl"

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

cecho "Uninstall Firewalld..." $boldyellow
yum -y remove firewalld

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $EXT_PACK >/dev/null
yum install -y -q $PRE_PACK >/dev/null

cecho "Downloading and installing CSF..." $boldyellow
cd /tmp
wget https://download.configserver.com/csf.tgz
tar zxvf csf.tgz >/dev/null 2>&1
cd /tmp/csf
sh install.sh >/dev/null 2>&1
perl /usr/local/csf/bin/csftest.pl
sed -i 's|TESTING = "1"|TESTING = "0"|g' /etc/csf/csf.conf
sed -i 's|PORTFLOOD = ""|PORTFLOOD = "80;tcp;50;10"|g' /etc/csf/csf.conf
sed -i 's|CONNLIMIT = ""|CONNLIMIT = "80;10"|g' /etc/csf/csf.conf
sed -i 's|CT_LIMIT = "0"|CT_LIMIT = "100"|g' /etc/csf/csf.conf
systemctl enable csf ; systemctl enable lfd
systemctl restart csf ; systemctl restart lfd
cecho "Download & install has been completed\n" $boldgreen
cecho " Adv security settings /etc/csf/csf.conf
Port Flood Protection: PORTFLOOD
Connection Limit Protection: CONNLIMIT
Connection Tracking: CT_LIMIT\n" $boldmagenta
cecho "Useful csf command options
Block an IP with CSF: csf -d < IP Address >
Allow an IP with CSF: csf -a < IP Address >
Unblock an IP with CSF: csf -dr < IP Address >
Unblock a temporarily blocked IP with CSF: csf -tr < IP Address >
Search IP Address: csf -g < IP Address >
" $boldwhite
