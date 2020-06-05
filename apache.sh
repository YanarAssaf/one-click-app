#!/bin/bash

### VARIABLES ###
PRE_PACK="wget vim autoconf libtool openssl-devel pcre-devel expat-devel"
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

cecho "Downloading Apache Packages..." $boldyellow
wget -q https://github.com/apache/httpd/archive/$VER.tar.gz && wget -q https://codeload.github.com/apache/apr/tar.gz/1.7.0 && wget -q https://github.com/apache/apr-util/archive/1.6.1.tar.gz
if [ $? -eq 0 ]
then
        cecho "Done." $boldgreen
        tar xzf $VER.tar.gz && tar xzf 1.6.1.tar.gz && tar xzf 1.7.0;
		cp -R apr-1.7.0 httpd-$VER/srclib/apr && cp -R apr-util-1.6.1 httpd-$VER/srclib/apr-util ;
else
        cecho "Error: Check Your Internet Connection *_*" $boldred
        exit 1
fi


cecho "=============================================================" $boldmagenta

cd /src/httpd-$VER
./buildconf
cecho "Starting configure..." $boldyellow
./configure --enable-ssl  --enable-so --enable-mpms-shared=all --with-included-apr --with-apr=/usr/local/apr/bin > /dev/null 2>&1
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

useradd apache
`echo 'pathmunge /usr/local/apache2/bin' > /etc/profile.d/httpd.sh`

`printf "[Unit]\nDescription=The Apache HTTP Server\nAfter=network.target\n\n[Service]\nType=forking\nExecStart=/usr/local/apache2/bin/apachectl -k start\nExecReload=/usr/local/apache2/bin/apachectl -k graceful\nExecStop=/usr/local/apache2/bin/apachectl -k graceful-stop\nPIDFile=/usr/local/apache2/logs/httpd.pid\nPrivateTmp=true\n\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/httpd.service`

systemctl daemon-reload
cp /usr/local/apache2/conf/extra/httpd-vhosts.conf /usr/local/apache2/conf/extra/httpd-vhosts.conf.bk
`sed -i '2s/^/ServerName localhost\n/' /usr/local/apache2/conf/httpd.conf`
`sed -i 's|DirectoryIndex index.html|DirectoryIndex index.html index.php|g' /usr/local/apache2/conf/httpd.conf`
`sed -i 's|#Include conf/extra/httpd-mpm.conf|Include conf/extra/httpd-mpm.conf|g' /usr/local/apache2/conf/httpd.conf`
`sed -i 's|#Include conf/extra/httpd-vhosts.conf|Include conf/extra/httpd-vhosts.conf|g' /usr/local/apache2/conf/httpd.conf`

mkdir /var/www
chmod 755 /var/www
chown root:root /var/www

mkdir /var/www/yanarit.com

chown apache:apache /var/www/yanarit.com

chmod 755 /var/www/yanarit.com


`printf "<VirtualHost *:80>\nServerName yanarit.com\n\n# Directory settings\nDocumentRoot /var/www/yanarit.com\n<Directory /var/www/yanarit.com>\nAllowOverride All\nRequire all granted\nOptions +FollowSymLinks -Indexes -Includes\n</Directory>\n\n# Logging\nErrorLog "/var/www/yanarit.com/httpd-error.log"\nCustomLog "/var/www/yanarit.com/httpd-access.log" common\n\n</VirtualHost>" > /usr/local/apache2/conf/extra/httpd-vhosts.conf`


`echo "^_^" > /var/www/yanarit.com/index.html`
setenforce 0
systemctl stop firewalld
apachectl configtest
systemctl start httpd
exit 0
