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

hostnamectl set-hostname master
cat <<EOF>> /etc/hosts
A.B.C.D master
A.B.C.D worker
EOF

systemctl stop firewalld && systemctl disable firewalld

setenforce 0
sed -i --follow-symlinks 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

cecho "Installing Prerequisite Packages..." $boldyellow
yum install -y yum-utils >/dev/null 2>&1

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1
	
cecho "Installing Packages..." $boldyellow
yum install -y kubelet kubeadm kubectl docker --disableexcludes=kubernetes >/dev/null 2>&1
systemctl enable kubelet; systemctl start kubelet; systemctl enable docker; systemctl start docker
cecho "Installation Completed..." $boldgreen

cecho "Initialization Kubernetes..." $boldyellow
kubeadm init --pod-network-cidr=10.244.0.0/16
cecho "Initialization complete..." $boldgreen

mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

yum install bash-completion -y >/dev/null 2>&1
curl \
    -L https://raw.githubusercontent.com/docker/compose/1.29.2/contrib/completion/bash/docker-compose \
    -o /etc/bash_completion.d/docker-compose >/dev/null 2>&1

echo 'source <(kubectl completion bash)' >>~/.bashrc
kubectl completion bash >/etc/bash_completion.d/kubectl
echo 'source <(kubeadm completion bash)' >>~/.bashrc
kubeadm completion bash >/etc/bash_completion.d/kubeadm

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml >/dev/null 2>&1

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.4.0/aio/deploy/recommended.yaml >/dev/null 2>&1
kubectl --namespace kubernetes-dashboard patch svc kubernetes-dashboard -p '{"spec": {"type": "NodePort"}}' >/dev/null 2>&1
kubectl get svc -n kubernetes-dashboard kubernetes-dashboard -o yaml > kubernetes-dashboard.yml
sed -i 's/nodePort: \b[0-9]\{5\}\b/nodePort: 30000/g' kubernetes-dashboard.yml
kubectl -n kubernetes-dashboard patch svc kubernetes-dashboard --patch "$(cat kubernetes-dashboard.yml)" >/dev/null 2>&1

cat <<EOF > ./admin.yml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: yanar-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: yanar-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: yanar-admin
    namespace: kube-system
EOF

kubectl apply -f ./admin.yml >/dev/null 2>&1
SA_NAME="yanar-admin"
cecho "token is created, you can access your Kubernetes Dashboard with it..." $boldyellow
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep ${SA_NAME} | awk '{print $1}')

cecho "Kubernetes Dashboard http://master:3000..." $boldyellow
cecho "token is created, you can access your Kubernetes Dashboard with it..." $boldyellow

exit 0
