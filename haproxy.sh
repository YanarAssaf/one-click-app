#!/bin/bash

### VARIABLES ###
PRE_PACK="make gcc"
VER="2.1.5"

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

cecho "Installing Prerequisite Packages" $boldyellow
yum install -y -q $PRE_PACK >/dev/null

mkdir -p /src
cd /src

wget -q http://www.haproxy.org/download/2.1/src/haproxy-$VER.tar.gz
if [ $? -eq 0 ]; then
    cecho "Downloaded Complete" $boldgreen
    tar xzf haproxy-$VER.tar.gz && rm -f haproxy*.tar.gz
    cd haproxy-$VER
else
    cecho "Not Downloaded The File Check Your Internet Connection" $boldred
    exit 1
fi

cecho "Configuring and Making HAPROXY" $boldyellow
make TARGET=linux-glibc CPU=x86_64
if [ $? -eq 0 ]; then
    cecho "Successfully Finshed From Combile" $boldgreen
else
    cecho "Error Not Compile Please Check Prerequisite Packages" $boldred
    exit 1
fi

cecho "Installing HAPROXY" $boldyellow
make install
if [ $? -eq 0 ]; then
    cecho "Successfully installed HAPROXY" $boldgreen
else
    cecho "Error Not Instaleed Please Check Compile Process" $boldred
    exit 1
fi

cecho "Adding HAProxy User" $boldyellow
id -u haproxy &>/dev/null || useradd -s /usr/sbin/nologin -r haproxy

cecho "Creating config and Adding Daemon" $boldyellow

cp /usr/local/sbin/haproxy* /usr/sbin/                                       # copy binaries to /usr/sbin
cp /src/haproxy-$VER/examples/haproxy.init /etc/init.d/haproxy               # copy init script in /etc/init.d
chmod +x /etc/init.d/haproxy                                                 # setting permission on init script
mkdir -p /etc/haproxy                                                        # creating directory where the config file must reside
cp /src/haproxy-$VER/examples/option-http_proxy.cfg /etc/haproxy/haproxy.cfg # copy example config file
mkdir -p /var/lib/haproxy                                                    # create directory for stats file
touch /var/lib/haproxy/stats                                                 # creating stats file

cecho "checking config and starting service" $boldyellow
service haproxy check # checking configuration file is valid
chkconfig haproxy on  # setting haproxy to start with VM

exit 0
