#!/bin/bash

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


cecho "Updating repo..." $boldyellow
sed -i -e '/^mirrorlist/d;/^#baseurl=/{s,^#,,;s,/mirror,/vault,;}' /etc/yum.repos.d/CentOS*.repo

cecho "Install has been completed" $boldgreen

: '
wget vim net-tools htop mtr ntp rsync bash-completion bash-completion-extras
### Secure SSH
	used ssh key
	edit sshd_config to
	PasswordAuthentication no
	RSAAuthentication yes
	PubkeyAuthentication yes
	ChallengeResponseAuthentication no
	PermitEmptyPasswords no
	UsePAM no 
'

exit 0
