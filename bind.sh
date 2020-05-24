#!/bin/bash

### VARIABLES ###
PRE_PACK="wget vim gcc openssl-devel perl libxml2-devel"
VER="9.11.2"

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
return
}
clear

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q $PRE_PACK > /dev/null
mkdir -p /src
cd /src

cecho "Downloading BIND Packages..." $boldyellow
wget -q -O bind-$VER.tar.gz https://www.isc.org/downloads/file/bind-$VER/
if [ $? -eq 0 ]
then
        cecho "Done." $boldgreen
        tar xzf bind-$VER.tar.gz;
else
        cecho "Error: Check Your Internet Connection *_*" $boldred
        exit 1
fi


cecho "=============================================================" $boldmagenta

cd /src/bind-9.11.2
cecho "Starting configure..." $boldyellow
./configure --with-openssl --enable-threads --with-libxml2 --sysconfdir=/etc > /dev/null 2>&1
if [ $? -eq 0 ]
then
	cecho "Starting make..." $boldyellow
	`make > /dev/null 2>&1`
	cecho "Starting make install..." $boldyellow
	`make install > /dev/null 2>&1`
	if [ $? -eq 0 ]
		then
			cecho "Done." $boldgreen
		else
			cecho "Error: ./make || ./make install *_*" $boldred
        exit 1
	fi
		
else
        cecho "Error: ./buildconf || ./configure *_*" $boldred
        exit 1
fi

groupadd named
useradd -d /var/named -g named -s /bin/false named
mkdir -p /var/named ; mkdir -p /var/named/data ; mkdir -p /var/named/forward ; mkdir -p /var/named/reverse ; mkdir -p /run/named
chown -R named:named /var/named
chmod -R 755 /var/named
chown named.named /run/named
cecho "Please copy rndc-key from /etc/rndc.conf to named.conf" $boldred
rndc-confgen -r /dev/urandom > /etc/rndc.conf

`printf "[Unit]\nDescription=Berkeley Internet Name Domain (DNS)\nAfter=network.target\n\n[Service]\nType=forking\nEnvironment=NAMEDCONF=/etc/named.conf\nEnvironmentFile=-/etc/sysconfig/named\nPIDFile=/run/named/named.pid\nExecStart=/usr/local/sbin/named -u named -c \\$NAMEDCONF\nExecReload=/bin/sh -c '/usr/local/sbin/rndc reload > /dev/null 2>&1 || /bin/kill -HUP \\$MAINPID'\nExecStop=/bin/sh -c '/usr/local/sbin/rndc stop > /dev/null 2>&1 || /bin/kill -TERM \\$MAINPID'\nPrivateTmp=true\n\n[Install]\nWantedBy=multi-user.target" > /usr/lib/systemd/system/named.service`
`printf "options {\n\tdirectory \\"/var/named\\";\n\trate-limit {\n\t\tresponses-per-second 10;\n\t\tlog-only no;\n\t};\n\tforwarders { 8.8.8.8; 8.8.4.4; };\n\tminimal-responses yes;\n\tminimal-any yes;\n\tallow-transfer {78.110.96.11;};\n};\n\nlogging {\n\tchannel critical {\n\tfile \\"/var/named/data/nscritical\\" versions 10 size 100M;\n\tseverity critical;\n\tprint-category yes;\n\tprint-severity yes;\n\tprint-time yes;\n\t};\n\tcategory security { critical; };\n\tcategory default { null; };\n};" > /etc/named.conf`
chown named.named -R /etc/named.conf

systemctl daemon-reload
setenforce 0
systemctl stop firewalld
cecho "named-checkconf" $boldyellow
`named-checkconf`
cecho "Starting named daemon" $boldgreen
systemctl start named
cecho "### Useful Command ###" $boldgreen
cecho "ps -ef | grep named, netstate -nulp | grep 53, rndc dumpdb -zones, rndc dumpdb -cache " $boldmagenta

exit 0
