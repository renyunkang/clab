#!/bin/bash
date
set -v

name="spiderpool"
images=(ghcr.io/spidernet-io/spiderpool/spiderpool-controller:v0.9.3 ghcr.io/spidernet-io/spiderpool/spiderpool-agent:v0.9.3 ghcr.io/spidernet-io/spiderpool/spiderpool-plugins:v0.9.2 ghcr.io/k8snetworkplumbingwg/multus-cni:v3.9.3)
MACVLAN_MASTER_INTERFACE="eth0"
NUM_WORKERS=1

worker_nodes=""
for ((i=1; i<=NUM_WORKERS; i++))
do
  worker_nodes="$worker_nodes
- role: worker"
done

cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.27.10 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30880
    hostPort: 30880
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30881
    hostPort: 30881
    listenAddress: "0.0.0.0"
    protocol: tcp
$worker_nodes
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

cp /root/.kube/config /root/.kube/config-${name}

# install cni
for i in "${images[@]}"
do
    docker pull $i
    kind load docker-image --name=${name} $i
done

helm repo add spiderpool https://spidernet-io.github.io/spiderpool
helm repo update spiderpool
# helm install spiderpool spiderpool/spiderpool --namespace kube-system --set plugins.installCNI=true --kubeconfig=/root/.kube/config-${name}
helm install spiderpool spiderpool/spiderpool --namespace kube-system --set multus.multusCNI.defaultCniCRName="ipvlan-conf" --set plugins.installCNI=true --kubeconfig=/root/.kube/config-${name}

kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app.kubernetes.io/name=spiderpool' -A --kubeconfig=/root/.kube/config-${name}


cat <<EOF | kubectl apply -f -
apiVersion: spiderpool.spidernet.io/v2beta1
kind: SpiderIPPool
metadata:
  name: ippool-test
spec:
  default: true
  ips:
  - "172.18.0.131-172.18.0.140"
  subnet: 172.18.0.0/16
  gateway: 172.18.0.1
  multusName:
  - kube-system/ipvlan-conf
EOF

kubectl delete SpiderMultusConfig -n kube-system ipvlan-conf
cat <<EOF | kubectl apply -f -
apiVersion: spiderpool.spidernet.io/v2beta1
kind: SpiderMultusConfig
metadata:
  name: ipvlan-conf
  namespace: kube-system
spec:
  cniType: ipvlan
  enableCoordinator: true
  ipvlan:
    master:
    - ${MACVLAN_MASTER_INTERFACE}
EOF

cat <<EOF | kubectl create -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: whoami
spec:
  replicas: 2
  selector:
    matchLabels:
      app: whoami
  template:
    metadata:
      annotations:
        ipam.spidernet.io/ippool: |-
          {
            "ipv4": ["ippool-test"]
          }
      labels:
        app: whoami
    spec:
      containers:
      - name: whoami
        image: rykren/whoami
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: whoami-svc
  labels:
    app: whoami
spec:
  type: ClusterIP
  ports:
    - port: 80
      protocol: TCP
      targetPort: 80
  selector:
    app: whoami 
EOF

echo "# begin kind cluster-${name}" >> ~/.bash_aliases
echo "alias kubectl-${name}='kubectl --kubeconfig=/root/.kube/config-4.0'" >> ~/.bash_aliases
echo "# end kind cluster-${name}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

source ~/.bashrc
