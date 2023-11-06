#!/bin/bash
date
set -v

name="openelb"
REPO=${REPO:-rykren}
TAG=${TAG:-refactor}
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
#k8simages="kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315"
k8simages="kindest/node:v1.24.3"

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=${k8simages} --config=-
kind: Cluster
name: ${name}
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
networking:
  kubeProxyMode: "ipvs"
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

# 2.remove taints
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl label $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master=""
kubectl get nodes -o wide

# 3.load image
kind load docker-image --name=${name} ${REPO}/openelb-controller:${TAG}
kind load docker-image --name=${name} ${REPO}/openelb-speaker:${TAG}
kind load docker-image --name=${name} kubesphere/kube-keepalived-vip:0.35
kind load docker-image --name=${name} rykren/whoami:latest
kind load docker-image --name=${name} calico/node:v3.26.1
kind load docker-image --name=${name} calico/pod2daemon-flexvol:v3.26.1
kind load docker-image --name=${name} calico/kube-controllers:v3.26.1
kind load docker-image --name=${name} calico/cni:v3.26.1
kind load docker-image --name=${name} registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.1.1

# 4.config cni and load images
kubectl apply -f ./calico.yaml
kubectl apply -f ./openelb.yaml
kubectl set image -n openelb-system deployment/openelb-controller *="${REPO}/openelb-controller:${TAG}"
kubectl set image -n openelb-system daemonset/openelb-speaker *="${REPO}/openelb-speaker:${TAG}"

