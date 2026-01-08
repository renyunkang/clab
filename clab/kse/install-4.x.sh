#!/bin/bash
date
set -v

name="test"

cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.27.10 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30880
    hostPort: 31880
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30881
    hostPort: 31881
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-test
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-test

# 4.2.0
chart=oci://hub.kubesphere.com.cn/kse/ks-core
version=1.2.1
helm upgrade --install -n kubesphere-system --create-namespace ks-core $chart --debug --wait --version $version --reset-values --set ha.enabled=true 
# --set redisHA.enabled=true

echo "# begin kind cluster-${name}" >> ~/.bash_aliases
echo "alias ktest='kubectl --kubeconfig=/root/.kube/config-test'" >> ~/.bash_aliases
echo "# end kind cluster-${name}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

source ~/.bashrc
