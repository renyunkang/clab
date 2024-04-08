#!/bin/bash
date
set -v

name="kse2"

cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30880
    hostPort: 30881
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-3.5.2
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-3.5.2
kubectl apply -f ./installer-3.5.0.yaml --kubeconfig=/root/.kube/config-3.5.2
kubectl apply -f ./cluster-3.5.0.yaml --kubeconfig=/root/.kube/config-3.5.2

echo "# begin kind cluster-${name}" >> ~/.bash_aliases
echo "alias kubectl2='kubectl --kubeconfig=/root/.kube/config-3.5.2'" >> ~/.bash_aliases
echo "# end kind cluster-${name}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases
source ~/.bashrc

