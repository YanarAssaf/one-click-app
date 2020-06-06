#!/bin/bash

### VARIABLES ###
PRE_PACK="make gcc wget systemd-devel"
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

wget -q https://www.haproxy.org/download/2.1/src/haproxy-$VER.tar.gz
if [ $? -eq 0 ]; then
    cecho "Downloaded Complete" $boldgreen
    tar xzf haproxy-$VER.tar.gz && rm -f haproxy*.tar.gz
    cd haproxy-$VER
else
    cecho "Not Downloaded The File Check Your Internet Connection" $boldred
    exit 1
fi

cecho "Configuring and Making HAPROXY" $boldyellow
make TARGET=linux-glibc CPU=x86_64 USE_SYSTEMD=1

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

cp /usr/local/sbin/haproxy* /usr/sbin/                                        # copy binaries to /usr/sbin
#cp /src/haproxy-$VER/examples/haproxy.init /etc/init.d/haproxy               # copy init script in /etc/init.d
#chmod +x /etc/init.d/haproxy                                                 # setting permission on init script
#cp /src/haproxy-$VER/contrib/systemd/haproxy.service.in /lib/systemd/system
$(printf "[Unit]\nDescription=HAProxy Load Balancer\nAfter=network.target\n\n[Service]\nExecStartPre=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q\nExecStart=/usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid\nExecReload=/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c -q\nExecReload=/bin/kill -USR2 $MAINPID\nKillMode=mixed\nRestart=always\nSuccessExitStatus=143\nType=notify\n\n[Install]\nWantedBy=multi-user.target" >/usr/lib/systemd/system/haproxy.service)
systemctl daemon-reload
mkdir -p /etc/haproxy                                                         # creating directory where the config file must reside
#cp /src/haproxy-$VER/examples/option-http_proxy.cfg /etc/haproxy/haproxy.cfg  # copy example config file
$(printf "global\n\tdaemon\n\tmaxconn 524252\n\tulimit-n 1048563\n\tnbproc 15\n\ndefaults\n\ttimeout connect 5000ms\n\ttimeout client 50000ms\n\ttimeout server 50000ms\n\nlisten proxys\n\tmode tcp\n\tlog global\n\tbind :80\n\tmaxconn 524252\n\t#balance roundrobin\n\tbalance source\n\tbind-process all\n\toption http-keep-alive\n\toption nolinger\n\toption redispatch\n\tsource 0.0.0.0 usesrc clientip\n\tserver cache1 192.168.100.1:3129 check port 3129 inter 2000 fall 3\n\toption tcp-smart-accept\n\toption tcp-smart-connect\n\nlisten stats\n\tbind :8888\n\tmode http\n\tstats enable\n\tstats refresh 30s\n\tstats show-node\n\tstats auth admin:password\n\tstats uri  /" >/etc/haproxy/haproxy.cfg)
mkdir -p /var/lib/haproxy                                                     # create directory for stats file
touch /var/lib/haproxy/stats                                                  # creating stats file

cecho "checking config and starting service" $boldyellow
#service haproxy check # checking configuration file is valid
#chkconfig haproxy on  # setting haproxy to start with VM
systemctl enable haproxy && systemctl start haproxy

exit 0
