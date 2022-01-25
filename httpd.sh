#!/bin/bash

### VARIABLES ###
EXT_PACK="wget vim net-tools htop mtr ntp rsync bash-completion bash-completion-extra" 
PRE_PACK="autoconf libtool openssl-devel pcre-devel expat-devel"
VER="2.4.52"

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

systemctl stop firewalld && systemctl disable firewalld
setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q epel-release >/dev/null
yum install -y -q $EXT_PACK >/dev/null
yum install -y -q $PRE_PACK >/dev/null
cd /tmp

cecho "Downloading and installing Httpd..." $boldyellow
wget -q https://github.com/apache/httpd/archive/$VER.tar.gz ; wget -q https://codeload.github.com/apache/apr/tar.gz/1.7.0 ; wget -q https://github.com/apache/apr-util/archive/1.6.1.tar.gz
tar xzf $VER.tar.gz ; tar xzf 1.6.1.tar.gz ; tar xzf 1.7.0
cp -R apr-1.7.0 httpd-$VER/srclib/apr ; cp -R apr-util-1.6.1 httpd-$VER/srclib/apr-util

cd /tmp/httpd-$VER
./buildconf >/dev/null 2>&1
./configure --sysconfdir=/etc/httpd --enable-ssl --enable-so --enable-mpms-shared=all --with-included-apr --with-apr=/usr/local/apr/bin >/dev/null 2>&1
if [ $? -eq 0 ]; then
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
else
    cecho "Installation Failed" $boldred
    exit 1
fi

cecho "Download & install has been completed" $boldgreen

useradd apache
echo 'pathmunge /usr/local/apache2/bin' >/etc/profile.d/httpd.sh
printf "[Unit]\nDescription=The Apache HTTP Server\nAfter=network.target\n\n[Service]\nType=forking\nExecStart=/usr/local/apache2/bin/apachectl -k start\nExecReload=/usr/local/apache2/bin/apachectl -k graceful\nExecStop=/usr/local/apache2/bin/apachectl -k graceful-stop\nPIDFile=/usr/local/apache2/logs/httpd.pid\nPrivateTmp=true\n\n[Install]\nWantedBy=multi-user.target" >/etc/systemd/system/httpd.service

systemctl daemon-reload
mkdir /etc/httpd/conf.d
sed -i '2s/^/ServerName localhost\n/' /etc/httpd/httpd.conf
sed -i 's|DirectoryIndex index.html|DirectoryIndex index.html index.php|g' /etc/httpd/httpd.conf
sed -i 's|#Include /etc/httpd/extra/httpd-vhosts.conf|Include /etc/httpd/conf.d/vhosts.conf|g' /etc/httpd/httpd.conf 

mkdir /var/www
chmod 755 /var/www
chown root:root /var/www

mkdir /var/www/site1
chown apache:apache /var/www/site1
chmod 755 /var/www/site1

printf "<VirtualHost *:80>\nServerName site1\n\n# Directory settings\nDocumentRoot /var/www/site1\n<Directory /var/www/site1>\nAllowOverride All\nRequire all granted\nOptions +FollowSymLinks -Indexes -Includes\n</Directory>\n\n# Logging\nErrorLog "/var/www/site1/httpd-error.log"\nCustomLog "/var/www/site1/httpd-access.log" common\n\n</VirtualHost>" >/etc/httpd/conf.d/vhosts.conf

echo "^_^" >/var/www/site1/index.html

/usr/local/apache2/bin/apachectl configtest
systemctl enable httpd ; systemctl restart httpd 

cecho "vhost.conf has been created /etc/httpd/conf.d/vhosts.conf" $boldgreen
cecho "Website directory /var/www/site1" $boldgreen
