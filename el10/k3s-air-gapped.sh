### Docker Server 

# K3s air-gapped 
VERSION="v1.36.4+k3s1"
mkdir /k3s ; cd /k3s
curl -Lo ./k3s https://github.com/k3s-io/k3s/releases/download/v1.36.4%2Bk3s1/k3s
curl -Lo install.sh https://get.k3s.io
curl -LO https://github.com/k3s-io/k3s-selinux/releases/download/v1.6.stable.1/k3s-selinux-1.6-1.el8.noarch.rpm


# Rancher air-gapped 
VERSION="v2.15.2"
curl -LO "https://github.com/rancher/rancher/releases/download/v2.15.2/rancher-images.txt"
curl -LO "https://github.com/rancher/rancher/releases/download/v2.15.2/rancher-save-images.sh"
curl -LO "https://github.com/rancher/rancher/releases/download/v2.15.2/rancher-load-images.sh"
chmod +x rancher-save-images.sh rancher-load-images.sh

./rancher-save-images.sh --image-list ./rancher-images.txt
./rancher-load-images.sh --image-list ./rancher-images.txt --registry <YOUR_LOCAL_REGISTRY>


### Rancher Server
tee -a /etc/hosts << 'EOF'
172.20.20.40 rancher
172.20.20.41 master1
172.20.20.42 master2
172.20.20.43 master3
172.20.20.177 registry.yanarit.com
172.20.20.44 worker1
172.20.20.45 worker2
172.20.20.46 worker3
EOF

mkdir -p /etc/rancher/k3s && sudo tee /etc/rancher/k3s/registries.yaml > /dev/null << 'EOF'
mirrors:
  "docker.io":
    endpoint:
      - "https://registry.yanarit.com"
  "registry.k8s.io":
    endpoint:
      - "https://registry.yanarit.com"
configs:
  "registry.yanarit.com":
    auth:
      username: admin
      password: 'Pa$$w0rd'
    tls:
      ca_file: /etc/rancher/k3s/nexus.crt
EOF

cd /k3s
cp ./nexus.crt /etc/pki/ca-trust/source/anchors/nexus.crt	  
cp ./nexus.crt /etc/rancher/k3s/nexus.crt
update-ca-trust   
	
docker run -d --restart=unless-stopped \
  -p 80:80 -p 443:443 \
  --privileged \
  -v /etc/rancher/k3s/registries.yaml:/etc/rancher/k3s/registries.yaml:ro \
  -v /etc/pki/ca-trust/source/anchors/nexus.crt:/etc/rancher/k3s/nexus.crt:ro \
  -e CATTLE_SYSTEM_DEFAULT_REGISTRY=registry.yanarit.com \
  -e CATTLE_SYSTEM_CATALOG=bundled \
  --add-host registry.yanarit.com:172.20.20.177 \
  --name rancher \
  registry.yanarit.com/rancher/rancher:v2.15.2
  
  
docker exec rancher cat /etc/rancher/k3s/registries.yaml
docker exec rancher ls -l /etc/rancher/k3s/nexus.crt
docker exec -it rancher kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get pods -A -w
docker exec rancher kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml -n kube-system describe pod -l k8s-app=kube-dns
docker exec -it rancher kubectl get pods -A
docker logs rancher 2>&1 | grep "Bootstrap Password"


### K3s Server
tee -a /etc/hosts << 'EOF'
172.20.20.40 rancher
172.20.20.41 master1
172.20.20.42 master2
172.20.20.43 master3
172.20.20.44 worker1
172.20.20.45 worker2
172.20.20.46 worker3
172.20.20.177 registry.yanarit.com
EOF


systemctl disable firewalld --now
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

mkdir -p /etc/rancher/k3s && sudo tee /etc/rancher/k3s/registries.yaml > /dev/null << 'EOF'
mirrors:
  "docker.io":
    endpoint:
      - "https://registry.yanarit.com"
  "registry.k8s.io":
    endpoint:
      - "https://registry.yanarit.com"
configs:
  "registry.yanarit.com":
    auth:
      username: admin
      password: 'Pa$$w0rd'
    tls:
      ca_file: /etc/rancher/k3s/nexus.crt
EOF

cd /k3s
dnf install -y epel-release
dnf install -y kernel-modules-extra nfs-utils tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion cloud-utils-growpart
dnf install -y ./k3s-selinux-1.6-1.el8.noarch.rpm
cp k3s /usr/local/bin/ ; chmod +x /usr/local/bin/k3s ; chmod +x ./install.sh
cp ./nexus.crt /etc/pki/ca-trust/source/anchors/nexus.crt	  
cp ./nexus.crt /etc/rancher/k3s/nexus.crt
update-ca-trust   

ip route del default via 172.20.20.77 dev ens34 ; ip route add default via 172.20.20.70 dev ens34

# master1
INSTALL_K3S_SKIP_DOWNLOAD=true K3S_SYSTEM_DEFAULT_REGISTRY="registry.yanarit.com" INSTALL_K3S_EXEC='server --token=asdasd --cluster-init --disable-default-registry-endpoint --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'' ./install.sh

# master2
INSTALL_K3S_SKIP_DOWNLOAD=true K3S_SYSTEM_DEFAULT_REGISTRY="registry.yanarit.com" K3S_TOKEN=asdasd ./install.sh server --server https://172.20.20.41:6443 --disable-default-registry-endpoint --node-taint 'node-role.kubernetes.io/control-plane:NoSchedule'

# worker1
INSTALL_K3S_SKIP_DOWNLOAD=true K3S_SYSTEM_DEFAULT_REGISTRY="registry.yanarit.com" K3S_TOKEN=asdasd ./install.sh agent --server https://172.20.20.41:6443 --disable-default-registry-endpoint

#Grafana
• Dashboard IDs deployed: 1860, 14205 , 15760 ,  (Node Exporter Full) and 13332 (Kubernetes Cluster).
#Prom
  - job_name: 'node-exporter'
    static_configs:
      - targets:
        - '172.20.20.41:9100'  # master1
        - '172.20.20.42:9100'  # master2
        - '172.20.20.43:9100'  # master3
        - '172.20.20.44:9100'  # worker1
        - '172.20.20.45:9100'  # worker2

  - job_name: 'kube-state-metrics'
    static_configs:
      - targets:
        - '172.20.20.41:8080'
        - '172.20.20.42:8080'
        - '172.20.20.43:8080'
        labels: {cluster: "kubernetes"}

  - job_name: 'cadvisor'
    metrics_path: '/metrics/cadvisor'
    static_configs:
      - targets:
        - '172.20.20.41:10255'
        - '172.20.20.42:10255'
        - '172.20.20.43:10255'
        - '172.20.20.44:10255'
        - '172.20.20.45:10255'
        labels: {cluster: "kubernetes"}


# K3s masters
echo -e "\nkubelet-arg:\n  - \"read-only-port=10255\"" | sudo tee -a /etc/rancher/k3s/config.yaml ; sudo systemctl restart k3s

# K3s workers
echo -e "\nkubelet-arg:\n  - \"read-only-port=10255\"" | sudo tee -a /etc/rancher/k3s/config.yaml ; sudo systemctl restart k3s-agent


kube-state-metrics.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: kube-state-metrics
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: kube-state-metrics
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets", "nodes", "pods", "services", "resourcequotas", "replicationcontrollers", "limitranges", "persistentvolumeclaims", "persistentvolumes", "namespaces", "endpoints"]
  verbs: ["list", "watch"]
- apiGroups: ["apps"]
  resources: ["statefulsets", "daemonsets", "deployments", "replicasets"]
  verbs: ["list", "watch"]
- apiGroups: ["batch"]
  resources: ["cronjobs", "jobs"]
  verbs: ["list", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["list", "watch"]
- apiGroups: ["authentication.k8s.io"]
  resources: ["tokenreviews"]
  verbs: ["create"]
- apiGroups: ["authorization.k8s.io"]
  resources: ["subjectaccessreviews"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kube-state-metrics
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: kube-state-metrics
subjects:
- kind: ServiceAccount
  name: kube-state-metrics
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
    spec:
      hostNetwork: true
      serviceAccountName: kube-state-metrics
      nodeSelector:
        node-role.kubernetes.io/control-plane: "true"
      tolerations:
      - operator: Exists # Required to allow scheduling on control-plane nodes
      containers:
      - name: kube-state-metrics
        image: registry.yanarit.com/rancher/kube-state-metrics/kube-state-metrics:v2.20.0
        ports:
        - containerPort: 8080
          hostPort: 8080
          name: http-metrics		  
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
  namespace: kube-system
  labels:
    app: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      hostNetwork: true
      tolerations:
      - operator: Exists
      containers:
      - name: node-exporter
        image: registry.yanarit.com/rancher/prom/node-exporter:v1.12.1
        args:
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        ports:
        - containerPort: 9100
          hostPort: 9100
          name: metrics
        volumeMounts:
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: root
          mountPath: /host/root
          readOnly: true
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /


docker pull registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.20.0
docker pull prom/node-exporter:v1.12.1

kubectl get daemonset node-exporter -n kube-system
kubectl get deployment kube-state-metrics -n kube-system

