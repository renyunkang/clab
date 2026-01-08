#!/bin/bash
date
set -v

name="member"

cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.22.17 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
- role: worker
networking:
  # ipFamily: dual
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/22
  serviceSubnet: 10.233.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-${name}
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-${name}

