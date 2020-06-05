#!/bin/bash

### VARIABLES ###
PRE_PACK="perl-libwww-perl"
VER="2.4.43"

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

cecho "Disable Firewalld..." $boldyellow
systemctl stop firewalld && systemctl disable firewalld && systemctl mask firewalld

cecho "Download csf..." $boldyellow
cd /usr/src/
wget https://download.configserver.com/csf.tgz
tar zxvf csf.tgz
cd csf
cecho "Install csf..." $boldyellow
sh install.sh
perl /usr/local/csf/bin/csftest.pl
cecho "Enable csf..." $boldyellow
systemctl enable csf && systemctl enable lfd
systemctl restart csf && systemctl restart lfd
cecho "Installation Completed" $green
