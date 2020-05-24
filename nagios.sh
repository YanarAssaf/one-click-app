#!/bin/bash

### VARIABLES ###
PRE_PACK="wget httpd php gcc glibc glibc-common gd gd-devel make net-snmp unzip"
VER="4.3.1"

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

cecho ()
{
message=$1
color=$2
echo -e "$color$message" ; $Reset
}
clear

cecho "Installating PRE_PACK....." $boldyellow
yum -y -q install $PRE_PACK > /dev/null

mkdir -p /src
cd /src


#wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-$VER.tar.gz
torify wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-$VER.tar.gz > /dev/null
if [ $? -eq 0 ]
then
    cecho "Downloaded Complete" $boldgreen
    tar xzf nagios-$VER.tar.gz && rm -f nagios*.tar.gz;
    cd nagios-$VER
else
    cecho "Not Downloaded The File Check Your Internet Connection" $boldred
    exit 1
fi

cecho "Adding Nagios User" $boldyellow
useradd  nagios
groupadd nagcmd
usermod -a -G nagcmd nagios
usermod -a -G nagios,nagcmd apache


cecho "Compile Nagios ..." $boldyellow
./configure --with-command-group=nagcmd > /dev/null
if [ $? -eq 0 ]
then
    cecho "Compile Complete" $boldgreen
else
    cecho "Error in compile process please recheck PRE_PACK" $boldred
    exit 1
fi

cecho "Installating Nagios ..." $boldyellow
make_nagios=(all install install-init install-config install-commandmode install-webconf)
for x in "${make_nagios[@]}"
do
make $x > /dev/null
if [ $? -eq 0 ]
then
    cecho "Install Complete $x" $boldgreen
else
    cecho "Error in Install process please recheck Compile" $boldred
exit 1
fi
done

cecho "Copy configure" $boldyellow
cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers
/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

cecho "Start Services" $boldyellow
/etc/init.d/nagios start
/etc/init.d/httpd start

cecho "Create Nagios Admin" $boldyellow
htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin
cecho "Username: nagiosadmin, Password: nagiosadmin" $boldyellow
