#!/bin/bash
date
set -v

name="kse"
name2="kse2"
name3="kse3"

cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config=-
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
cp  /root/.kube/config  /root/.kube/config-1
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-1
kubectl apply -f ./installer-3.5.0.yaml --kubeconfig=/root/.kube/config-1
kubectl apply -f ./cluster-3.5.0.yaml --kubeconfig=/root/.kube/config-1

echo "# begin kind cluster-${name}" >> ~/.bash_aliases
echo "alias kubectl1='kubectl --kubeconfig=/root/.kube/config-1'" >> ~/.bash_aliases
echo "# end kind cluster-${name}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases



cat <<EOF | kind create cluster --name=${name2} --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config=-
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
  podSubnet: 10.234.64.0/18
  serviceSubnet: 10.234.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-2
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-2
kubectl apply -f ./installer-3.5.0.yaml --kubeconfig=/root/.kube/config-2
kubectl apply -f ./cluster-3.5-member.yaml --kubeconfig=/root/.kube/config-2

echo "# begin kind cluster-${name2}" >> ~/.bash_aliases
echo "alias kubectl2='kubectl --kubeconfig=/root/.kube/config-2'" >> ~/.bash_aliases
echo "# end kind cluster-${name2}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases


cat <<EOF | kind create cluster --name=${name3} --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30880
    hostPort: 30882
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
networking:
  disableDefaultCNI: true
  podSubnet: 10.235.64.0/18
  serviceSubnet: 10.235.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-3
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-3
kubectl apply -f ./installer-3.5.0.yaml --kubeconfig=/root/.kube/config-3
kubectl apply -f ./cluster-3.5-single.yaml --kubeconfig=/root/.kube/config-3

echo "# begin kind cluster-${name3}" >> ~/.bash_aliases
echo "alias kubectl3='kubectl --kubeconfig=/root/.kube/config-3'" >> ~/.bash_aliases
echo "# end kind cluster-${name3}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

source ~/.bashrc
