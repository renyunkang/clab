#!/bin/bash
date
set -v

name1="cil-native"
name2="cil-tunnel"
name3="cil-eproute"
k8simages="kindest/node:v1.29.2"

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name1} --image=${k8simages} --config=-
kind: Cluster
name: ${name1}
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

cp /root/.kube/config /root/.kube/config-${name1}

cat <<EOF | kind create cluster --name=${name2} --image=${k8simages} --config=-
kind: Cluster
name: ${name2}
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 32000
    hostPort: 32000
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
  extraPortMappings:
  - containerPort: 32100
    hostPort: 32100
    listenAddress: "0.0.0.0"
    protocol: tcp

networking:
  kubeProxyMode: "ipvs"
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

cp /root/.kube/config /root/.kube/config-${name2}

cat <<EOF | kind create cluster --name=${name3} --image=${k8simages} --config=-
kind: Cluster
name: ${name3}
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 33000
    hostPort: 33000
    listenAddress: "0.0.0.0"
    protocol: tcp
- role: worker
  extraPortMappings:
  - containerPort: 33100
    hostPort: 33100
    listenAddress: "0.0.0.0"
    protocol: tcp

networking:
  kubeProxyMode: "ipvs"
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

cp /root/.kube/config /root/.kube/config-${name3}

# 2.remove taints
controller_node_ip=`kubectl get node -o wide --kubeconfig=/root/.kube/config-${name1} --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl --kubeconfig=/root/.kube/config-${name1} taint nodes $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name1} | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl --kubeconfig=/root/.kube/config-${name1} label $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name1} | grep control-plane) node-role.kubernetes.io/control-plane=""
kubectl get nodes -o wide --kubeconfig=/root/.kube/config-${name1}

controller_node_ip=`kubectl get node -o wide --kubeconfig=/root/.kube/config-${name2} --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl --kubeconfig=/root/.kube/config-${name2} taint nodes $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name2} | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl --kubeconfig=/root/.kube/config-${name2} label $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name2} | grep control-plane) node-role.kubernetes.io/control-plane=""
kubectl get nodes -o wide --kubeconfig=/root/.kube/config-${name2}

controller_node_ip=`kubectl get node -o wide --kubeconfig=/root/.kube/config-${name3} --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl --kubeconfig=/root/.kube/config-${name3} taint nodes $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name3} | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl --kubeconfig=/root/.kube/config-${name3} label $(kubectl get nodes -o name --kubeconfig=/root/.kube/config-${name3} | grep control-plane) node-role.kubernetes.io/control-plane=""
kubectl get nodes -o wide --kubeconfig=/root/.kube/config-${name3}

# 3.deploy cilium
helm install cilium cilium/cilium --kubeconfig=/root/.kube/config-${name1} --version 1.16.0 --namespace kube-system --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set autoDirectNodeRoutes=true

helm install cilium cilium/cilium --kubeconfig=/root/.kube/config-${name2} --version 1.16.0 --namespace kube-system

helm install cilium cilium/cilium --kubeconfig=/root/.kube/config-${name3} --version 1.16.0 --namespace kube-system --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set autoDirectNodeRoutes=true --set endpointRoutes.enabled=true

# helm install cilium cilium/cilium --version 1.15.6 --namespace kube-system --set cni.chainingMode=generic-veth --set cni.customConf=true --set cni.configMap=cni-configuration --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native

# https://docs.cilium.io/en/stable/observability/metrics/
# kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.15.7/examples/kubernetes/addons/prometheus/monitoring-example.yaml

#helm install cilium cilium/cilium --version 1.16.0 --namespace kube-system --set cni.chainingMode=generic-veth --set cni.chainingTarget=k8s-pod-network --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set hubble.relay.enabled=true --set hubble.ui.enabled=true --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}"
# helm install cilium cilium/cilium --version 1.15.6 --namespace kube-system --set cni.chainingMode=generic-veth --set cni.chainingTarget=k8s-pod-network --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set hubble.relay.enabled=true --set hubble.ui.enabled=true --set prometheus.enabled=true --set operator.prometheus.enabled=true --set hubble.metrics.enableOpenMetrics=true --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http,port-distribution}" 

