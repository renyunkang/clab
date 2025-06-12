#!/bin/bash
date
set -v

name="cil-native"
k8simages="kindest/node:v1.29.2"

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=${k8simages} --config=-
kind: Cluster
name: ${name}
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 31000
    hostPort: 31000
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
  extraPortMappings:
  - containerPort: 31100
    hostPort: 31100
    listenAddress: "0.0.0.0"
    protocol: tcp

networking:
  kubeProxyMode: "ipvs"
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

cp /root/.kube/config /root/.kube/config-${name}

# 2.remove taints
controller_node_ip=`kubectl get node -o wide --kubeconfig=/root/.kube/config-${name} --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl --kubeconfig=/root/.kube/config-${name} taint nodes $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name} | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl --kubeconfig=/root/.kube/config-${name} label $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name} | grep control-plane) node-role.kubernetes.io/control-plane=""
kubectl get nodes -o wide --kubeconfig=/root/.kube/config-${name}

# 3.deploy cilium
helm install cilium cilium/cilium --kubeconfig=/root/.kube/config-${name} --version 1.16.0 --namespace kube-system --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set autoDirectNodeRoutes=true

