#!/bin/bash

PRE_PACK="epel-release"
EXT_PACK="tar wget vim net-tools htop mtr nload tcpdump rsync bash-completion" 


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

cecho "create fluentbit user and role..." $boldyellow
cecho "Open Kibana → Dev Tools..." $boldyellow

cat <<'EOF'
PUT /_security/role/fluentbit_writer
{
  "cluster": [],
  "indices": [
    {
      "names": [
        "asp-k3s-logs-*",
        "asu-k3s-logs-*"
      ],
      "privileges": [
        "auto_configure",
        "create_index",
        "create_doc",
        "index",
        "write",
        "view_index_metadata"
      ]
    }
  ]
}
EOF

cat <<'EOF'
PUT /_security/user/fluentbit_writer
{
  "password": "pZZPvNGLnNBs",
  "roles": [
    "fluentbit_writer"
  ],
  "enabled": true
}
EOF

read -rp "Enter the Elasticsearch server IP: " SERVER_IP
scp "root@$SERVER_IP:/etc/elasticsearch/certs/http_ca.crt" /tmp/http_ca.crt

cat > efkns.yaml <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: logging
EOF

kubectl apply -f efkns.yaml

CERT_B64=$(base64 -w 0 /tmp/http_ca.crt)

cat > elasticsearch-ca.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: elasticsearch-ca
  namespace: logging
type: Opaque
data:
  http_ca.crt: ${CERT_B64}
EOF

kubectl apply -f elasticsearch-ca.yaml

ES_PASSWORD='pZZPvNGLnNBs'
PASSWORD_B64=$(printf '%s' "$ES_PASSWORD" | base64 -w 0)

cat > fluent-bit-es-auth.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: fluent-bit-es-auth
  namespace: logging
type: Opaque
data:
  username: $(printf '%s' 'fluentbit_writer' | base64 -w 0)
  password: ${PASSWORD_B64}
EOF

kubectl apply -f fluent-bit-es-auth.yaml
unset ES_PASSWORD PASSWORD_B64

cat > fluent-bit-asp.yaml <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fluent-bit
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fluent-bit-read
rules:
  - apiGroups: [""]
    resources: ["namespaces", "pods"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: fluent-bit-read-binding
subjects:
  - kind: ServiceAccount
    name: fluent-bit
    namespace: logging
roleRef:
  kind: ClusterRole
  name: fluent-bit-read
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: logging
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush              1
        Log_Level          info
        Daemon             off

    [INPUT]
        Name               tail
        Tag                kube.*
        Path               /var/log/containers/*.log
        multiline.parser   cri
        DB                 /var/lib/fluent-bit/flb_kube.db
        Mem_Buf_Limit      50MB
        Skip_Long_Lines    On
        Read_from_Head     On

    [FILTER]
        Name                kubernetes
        Match               kube.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Kube_Tag_Prefix     kube.var.log.containers.
        Merge_Log           On
        Keep_Log            Off

    [FILTER]
        Name                record_modifier
        Match               kube.*
        Record              cluster_id CLUSTER_ID

    [OUTPUT]
        Name                es
        Match               kube.*
        Host                SERVER_IP
        Port                9200
        HTTP_User           ${ES_USER}
        HTTP_Passwd         ${ES_PASSWORD}
        Logstash_Format     On
        Logstash_Prefix     LOGSTASH_PREFIX
        Time_Key            @timestamp
        Suppress_Type_Name  On
        tls                 On
        tls.verify          On
        tls.ca_file         /fluent-bit/tls/http_ca.crt
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluent-bit
  namespace: logging
spec:
  selector:
    matchLabels:
      app: fluent-bit
  template:
    metadata:
      labels:
        app: fluent-bit
    spec:
      serviceAccountName: fluent-bit
      containers:
        - name: fluent-bit
          image: cr.fluentbit.io/fluent/fluent-bit:3.2.4
          env:
            - name: ES_USER
              valueFrom:
                secretKeyRef:
                  name: fluent-bit-es-auth
                  key: username
            - name: ES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: fluent-bit-es-auth
                  key: password
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              memory: 512Mi
          volumeMounts:
            - name: varlog
              mountPath: /var/log
              readOnly: true
            - name: config
              mountPath: /fluent-bit/etc
              readOnly: true
            - name: elasticsearch-ca
              mountPath: /fluent-bit/tls
              readOnly: true
            - name: positions
              mountPath: /var/lib/fluent-bit
      terminationGracePeriodSeconds: 30
      volumes:
        - name: varlog
          hostPath:
            path: /var/log
        - name: config
          configMap:
            name: fluent-bit-config
        - name: elasticsearch-ca
          secret:
            secretName: elasticsearch-ca
        - name: positions
          hostPath:
            path: /var/lib/fluent-bit
            type: DirectoryOrCreate
EOF
read -rp "Enter the Logstash_Prefix: " LOGSTASH_PREFIX
read -rp "Enter the cluster_id: " CLUSTER_ID
sed -i "s#SERVER_IP#$SERVER_IP#g" fluent-bit-asp.yaml
sed -i "s#LOGSTASH_PREFIX#$LOGSTASH_PREFIX#g" fluent-bit-asp.yaml
sed -i "s#CLUSTER_ID#$CLUSTER_ID#g" fluent-bit-asp.yaml
kubectl apply -f fluent-bit-asp.yaml

#kubectl get pods -n logging -o wide
#kubectl delete namespace logging
#kubectl delete clusterrole fluent-bit-read --ignore-not-found
#kubectl delete clusterrolebinding fluent-bit-read-binding --ignore-not-found
#curl --cacert /etc/elasticsearch/certs/http_ca.crt -u elastic 'https://localhost:9200/_cat/indices/asp-k3s-logs-*?v'
#kubectl logs -n logging fluent-bit-2jm9c --tail=500 | grep -iE "error|warn|elastic"
#kubectl get cm -n logging -o yaml  

exit 0
