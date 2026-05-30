#!/bin/bash

### VARIABLES ###
PRE_PACK="gcc glibc glibc-common perl httpd php wget gd gd-devel s-nail postfix openssl-devel"
PRE_PACK1="make gettext automake autoconf  net-snmp net-snmp-utils perl-Net-SNMP nrpe nagios-plugins-nrpe"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 

VER="4.5.13"
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
wget -q -O nagioscore.tar.gz https://yanarit.com//nagios-4.5.13.tar.gz
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

cecho "commnad to install nrpe on clients" $boldgreen

echo ""

cecho "
  dnf config-manager --set-enabled crb
  dnf install nrpe nagios-plugins-all " $boldgreen

# check_esxi_hardware
read -p "Do you want to install check_esxi_hardware? (yes/no): " user_input

# Convert input to lowercase to handle variations like "Yes" or "YES"
user_input=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

# Evaluate the user response
if [[ "$user_input" == "yes" || "$user_input" == "y" ]]; then
    echo "Starting installation of check_esxi..."
    dnf install -y -q python3-pip s-nail python3-packaging >/dev/null
	pip3 install pywbem >/dev/null
	cd /usr/local/nagios/libexec/
	wget -q https://yanarit.com/check_esxi_hardware.py
	chown nagios:nagios check_esxi_hardware.py
	chmod 755 check_esxi_hardware.py

	cecho "commnad to install check_esxi_hardware" $boldgreen
	echo ""
	cecho "
	  1. enable CIM on ESXi
	  2. esxcli system wbem set --enable true
	  3. check_nrpe -H \$HOSTADDRESS\$ -c \$ARG1\$
	  4. check_esxi_hardware.py -H \$HOSTADDRESS\$ -U root -P \$USER5\$ -r -i "Memory,Power Supply,IPMI" " $boldgreen

    
else
    cecho "finished" $boldgreen
    
fi

mkdir -p /usr/local/nagios/etc/yanarit

cat << 'EOF' > /usr/local/nagios/etc/yanarit/hosts.cfg
define host {
    use                     linux-server
    host_name               esxi1
    alias                   esxi1
    address                 10.10.0.1
}

define host {
    use                     linux-server
    host_name               server1
    alias                   server1
    address                 10.10.0.2
}
EOF

cat << 'EOF' > /usr/local/nagios/etc/yanarit/services.cfg

define service {
    use                     local-service
    host_name               esxi1
    service_description     ESXi
    check_command           check_esxi
}

define service {
    use                     local-service
    host_name               server1
    service_description     Users
    check_command           check_nrpe_3var!check_users!0!1
	
}

EOF

cat << 'EOF' > /usr/local/nagios/etc/yanarit/commands.cfg

define command {

    command_name    check_esxi
    command_line    $USER1$/check_esxi_hardware.py -H $HOSTADDRESS$ -U root -P $USER5$ -r -i Memory,Power
}

define command {

    command_name    check_nrpe
    command_line    /usr/lib64/nagios/plugins/check_nrpe -H $HOSTADDRESS$ -c $ARG1$
}

define command {

    command_name    check_nrpe_3var
    command_line    /usr/lib64/nagios/plugins/check_nrpe -H $HOSTADDRESS$ -c $ARG1$ -a $ARG2$ $ARG3$
}

EOF

cecho "Created the following useful configuration objects /usr/local/nagios/etc/yanarit" $boldgreen
cecho "Run this command for the last few objects" $boldgreen
echo ""

cecho "
  echo "cfg_dir=/usr/local/nagios/etc/yanarit" >> /usr/local/nagios/etc/nagios.cfg " $boldgreen

cecho "done" $boldgreen
