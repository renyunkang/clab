#!/bin/bash
date
set -v

name="kse3"

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
- role: worker
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-3.5
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-3.5
kubectl apply -f ./installer-3.5.0.yaml --kubeconfig=/root/.kube/config-3.5
kubectl apply -f ./cluster-3.5.0.yaml --kubeconfig=/root/.kube/config-3.5

echo "# begin kind cluster-${name}" >> ~/.bash_aliases
echo "alias k3='kubectl --kubeconfig=/root/.kube/config-3.5'" >> ~/.bash_aliases
echo "# end kind cluster-${name}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases
source ~/.bashrc

