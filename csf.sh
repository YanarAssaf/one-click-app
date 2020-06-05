#!/bin/bash
systemctl stop firewalld && systemctl disable firewalld && systemctl mask firewalld
yum -y install perl-libwww-perl
cd /usr/src/
wget https://download.configserver.com/csf.tgz
tar zxvf csf.tgz
cd csf 
sh install.sh
perl /usr/local/csf/bin/csftest.pl
systemctl enable csf && systemctl enable lfd
systemctl restart csf && systemctl restart lfd
