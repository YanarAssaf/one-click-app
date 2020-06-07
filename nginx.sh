#!/bin/bash

### VARIABLES ###
PRE_PACK="yum-utils"
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

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y -q $PRE_PACK >/dev/null
$(printf "[nginx-stable]\nname=nginx stable repo\nbaseurl=http://nginx.org/packages/centos/\$releasever/\$basearch/\ngpgcheck=1\nenabled=1\ngpgkey=https://nginx.org/keys/nginx_signing.key\nmodule_hotfixes=true" >/etc/yum.repos.d/nginx.repo)
cecho "Installing Nginx..." $boldyellow
yum -y install nginx >/dev/null 2>&1
cecho "Installation Completed..." $boldgreen

exit 0
