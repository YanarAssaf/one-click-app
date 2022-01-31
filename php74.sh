#!/bin/bash

### VARIABLES ###
PRE_PACK="php php-fpm php-opcache php-devel php-mbstring php-mcrypt php-mysql php-mysqlnd php-phpunit-PHPUnit php-pecl-xdebug php-pecl-xhprof"
VER=""

# Setup Colours
boldblack='\E[1;30;40m'
boldred='\E[1;31;40m'
boldgreen='\E[1;32;40m'
boldyellow='\E[1;33;40m'
boldblue='\E[1;34;40m'

Reset="tput sgr0"

cecho() {
    message=$1
    color=$2
    echo -e "$color$message"
    $Reset
    return
}
clear

yum -y -q install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm >/dev/null
$(sed -i '9s|enabled=0|enabled=1|g' /etc/yum.repos.d/remi-php74.repo)
cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q $PRE_PACK >/dev/null

#Apache Setting
sed -i 's|#LoadModule proxy_module modules/mod_proxy.so|LoadModule proxy_module modules/mod_proxy.so|g' /etc/httpd/httpd.conf
sed -i 's|#LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|LoadModule proxy_fcgi_module modules/mod_proxy_fcgi.so|g' /etc/httpd/httpd.conf
sed -i 's|#LoadModule rewrite_module modules/mod_rewrite.so|LoadModule rewrite_module modules/mod_rewrite.so|g' /etc/httpd/httpd.conf

cecho "Setup Apache setting with fpm" $boldyellow
cecho '
    <LocationMatch "^/(.*\.php(/.*)?)$">
        ProxyPass fcgi://127.0.0.1:9000/var/www/ex/$1
    </LocationMatch>
    	
    <FilesMatch "\.php$">
        Require all granted
        SetHandler proxy:fcgi://127.0.0.1:9000
    </FilesMatch>
' $boldred

$(sed -i 's|short_open_tag = Off|short_open_tag = On|g' /etc/php.ini)
$(sed -i 's|expose_php = On|expose_php = Off|g' /etc/php.ini)
$(sed -i 's|;opcache.enable=0|opcache.enable=1|g' /etc/php.ini)
$(sed -i 's|;opcache.memory_consumption=64|opcache.memory_consumption=64|g' /etc/php.ini)
$(sed -i 's|;opcache.interned_strings_buffer=4|opcache.interned_strings_buffer=16|g' /etc/php.ini)
$(sed -i 's|;opcache.max_accelerated_files=2000|opcache.max_accelerated_files=7000|g' /etc/php.ini)
$(sed -i 's|;opcache.validate_timestamps=1|opcache.validate_timestamps=1|g' /etc/php.ini)
$(sed -i 's|;opcache.fast_shutdown=0|opcache.fast_shutdown=1|g' /etc/php.ini)
$(sed -i 's|disable_functions =|disable_functions = show_source, system, shell_exec, passthru, exec, phpinfo, popen, proc_open ,  phpmail|g' /etc/php.ini)
$(sed -i 's|;open_basedir =|open_basedir ="/var/www/"|g' /etc/php.ini)
$(sed -i 's|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|g' /etc/php.ini)
$(sed -i 's|;error_log = php_errors.log|error_log = php_errors.log|g' /etc/php.ini)

systemctl restart php-fpm

cecho '\n
# Optional PHP-FPM: Multiple Resource Pools \n
groupadd www-data
useradd -r -g www-data -s /sbin/nologin -M www-data
mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.bk
printf "[www]\\nuser = www-data\\ngroup = www-data\\nlisten = 127.0.0.1:9000\\nlisten.owner = apache\\nlisten.group = apache\\nphp_admin_value[disable_functions] = show_source, system, shell_exec, passthru, exec,  popen, proc_open ,  phpmail, phpinfo\\nphp_admin_flag[allow_url_fopen] = off\\nphp_admin_value[open_basedir] = /var/www/ex\npm = dynamic\\npm.max_children = 5\\npm.start_servers = 2\\npm.min_spare_servers = 1\\npm.max_spare_servers = 3\nchdir = / " > /etc/php-fpm.d/ex.conf
' $boldgreen

exit 0
