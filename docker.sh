#!/bin/bash
yum -y install yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce docker-ce-cli containerd.io
systemctl daemon-reload && systemctl restart docker 
curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Proxy
# /etc/yum.conf | proxy=http://51.15.80.136:3128
# mkdir /etc/systemd/system/docker.service.d
# /etc/systemd/system/docker.service.d/http-proxy.conf
# [Service]
# Environment="HTTP_PROXY=http://51.15.80.136:3128/"
