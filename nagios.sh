#!/bin/bash

### VARIABLES ###
PRE_PACK="yum-utils gcc glibc glibc-common wget unzip httpd php gd gd-devel perl postfix wget vim htop mtr ntp rsync bash-completion nrpe nagios-plugins-all check_nrpe" 
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

cecho "Disable Firewall & SELinux..." $boldyellow
systemctl stop firewalld && systemctl disable firewalld
setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $PRE_PACK >/dev/null


cecho "Download & Configure Nagios ..." $boldyellow
cd /tmp
wget -q -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.6.tar.gz >/dev/null
tar xzf nagioscore.tar.gz >/dev/null
cd /tmp/nagioscore-nagios-4.4.6/
./configure > /dev/null
if [ $? -eq 0 ]
then
    cecho "Download & configure has been completed" $boldgreen
else
    cecho "Download or configure failed" $boldred
    exit 1
fi

cecho "Compiling and Installing Nagios  ..." $boldyellow
make_nagios=(all install-groups-users install install-daemoninit install-commandmode install-config install-webconf)
for x in "${make_nagios[@]}"
do
make $x > /dev/null
if [ $? -eq 0 ]
then
    cecho "Compile Complete $x" $boldgreen
else
    cecho "Faild to compile $x" $boldred
exit 1
fi
done

usermod -a -G nagios apache

systemctl enable httpd.service; systemctl enable nagios.service; systemctl restart httpd.service; systemctl restart nagios.service

cecho "Create Nagios Admin" $boldyellow
htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin
cecho "Username: nagiosadmin, Password: nagiosadmin" $boldyellow
