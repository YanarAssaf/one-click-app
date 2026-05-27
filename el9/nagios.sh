#!/bin/bash

### VARIABLES ###
PRE_PACK="gcc glibc glibc-common perl httpd php wget gd gd-devel s-nail postfix openssl-devel"
PRE_PACK1="make gettext automake autoconf  net-snmp net-snmp-utils perl-Net-SNMP nrpe nagios-plugins-nrpe"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 

VER="4.5.12"
USER_FILE="/usr/local/nagios/etc/htpasswd.users"
USER_NAME="nagiosadmin"
USER_PASS="admin"

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

systemctl disable --now firewalld
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
dnf install -y -q epel-release >/dev/null
dnf install -y -q $PRE_PACK >/dev/null
dnf install -y -q $PRE_PACK1 >/dev/null
dnf install -y -q $EXT_PACK >/dev/null
cd /tmp

cecho "Downloading and installing Nagios..." $boldyellow
cd /tmp
#wget --output-document="nagioscore.tar.gz" $(wget -q -O - https://api.github.com/repos/NagiosEnterprises/nagioscore/releases/latest  | grep '"browser_download_url":' | grep -o 'https://[^"]*')
wget -q -O nagioscore.tar.gz https://yanarit.com//nagios-4.5.12.tar.gz
tar xzf nagioscore.tar.gz
cd /tmp/nagios-*


./configure >/dev/null 2>&1
if [ $? -eq 0 ]; then
	make all >/dev/null 2>&1
	make install-groups-users >/dev/null 2>&1
	usermod -a -G nagios apache >/dev/null 2>&1
	make install >/dev/null 2>&1
	make install-daemoninit >/dev/null 2>&1
	make install-commandmode >/dev/null 2>&1
	make install-config >/dev/null 2>&1
	make install-webconf >/dev/null 2>&1
else
    cecho "Installation Failed" $boldred
    exit 1
fi

cecho "Download & install has been completed" $boldgreen

htpasswd -cb "$USER_FILE" "$USER_NAME" "$USER_PASS"

systemctl --now enable httpd.service 
systemctl --now enable nagios.service

#Nagios-pligins
cd /tmp
wget -O nagios-plugins.tar.gz -q https://yanarit.com/nagios-plugins-2.5.tar.gz
tar zxf nagios-plugins.tar.gz
cd /tmp/nagios-plugins-*

./configure >/dev/null 2>&1
if [ $? -eq 0 ]; then
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
else
    cecho "Installation Failed" $boldred
    exit 1
fi

cecho "finished" $boldgreen
