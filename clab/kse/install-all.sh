#!/bin/bash
date
set -v

name="kse3"
name2="kse4"

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



cat <<EOF | kind create cluster --name=${name2} --image=kindest/node:v1.27.10 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30880
    hostPort: 30882
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30881
    hostPort: 30881
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
networking:
  disableDefaultCNI: true
  podSubnet: 10.234.64.0/18
  serviceSubnet: 10.234.0.0/18
EOF
cp  /root/.kube/config  /root/.kube/config-4.0
kubectl apply -f ./calico.yaml --kubeconfig=/root/.kube/config-4.0

helm upgrade --install -n kubesphere-system --create-namespace ks-core https://charts.kubesphere.io/test/ks-core-1.0.0.tgz --set apiserver.nodePort=30881 --debug --wait --kubeconfig=/root/.kube/config-4.0 --set cloud.enabled=false --set upgrade.enabled=false
helm template oci://hub.kubesphere.com.cn/kse/kse-extensions-publish --set museum.enabled=true  | kubectl create -f -

echo "# begin kind cluster-${name2}" >> ~/.bash_aliases
echo "alias k4='kubectl --kubeconfig=/root/.kube/config-4.0'" >> ~/.bash_aliases
echo "# end kind cluster-${name2}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

source ~/.bashrc
