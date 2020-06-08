#!/bin/bash
yum -y install http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

$(sed -i '9s|enabled=0|enabled=1|g' /etc/yum.repos.d/remi-php74.repo)

yum -y install php php-fpm php-opcache php-devel php-mbstring php-mcrypt php-mysql php-mysqlnd php-phpunit-PHPUnit php-pecl-xdebug php-pecl-xhprof -y

#Apache Setting
$(sed -i 's|#LoadModule proxy_module modules\/mod_proxy.so|LoadModule proxy_module modules\/mod_proxy.so|g' /usr/local/apache2/conf/httpd.conf)
$(sed -i 's|#LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi.so|LoadModule proxy_fcgi_module modules\/mod_proxy_fcgi.so|g' /usr/local/apache2/conf/httpd.conf)
$(sed -i 's|#LoadModule rewrite_module modules/mod_rewrite.so|LoadModule rewrite_module modules\/mod_rewrite.so|g' /usr/local/apache2/conf/httpd.conf)

echo '
    <LocationMatch "^/(.*\.php(/.*)?)$">
        ProxyPass fcgi://127.0.0.1:9000/var/www/ex/$1
    </LocationMatch>
    	
    <FilesMatch "\.php$">
        Require all granted
        SetHandler proxy:fcgi://127.0.0.1:9000
    </FilesMatch>
'

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

$(printf "<?php\nphpinfo();\n" >/var/www/ex/info.php)

systemctl restart php-fpm

exit 0
