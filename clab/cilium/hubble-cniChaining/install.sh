#!/bin/bash
date
set -v

name="calico-hubble"
master="${name}-control-plane"
node1="${name}-worker"
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
  - containerPort: 32000
    hostPort: 32000
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
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl label $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master=""
kubectl get nodes -o wide

# 3.deploy calico
kubectl apply -f https://raw.githubusercontent.com/renyunkang/clab/master/kind/calico/calico.yaml

# helm install cilium cilium/cilium --version 1.15.6 --namespace kube-system --set cni.chainingMode=generic-veth --set cni.customConf=true --set cni.configMap=cni-configuration --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native

# https://docs.cilium.io/en/stable/observability/metrics/
# kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.15.7/examples/kubernetes/addons/prometheus/monitoring-example.yaml

helm install cilium cilium/cilium --version 1.15.6 --namespace kube-system --set cni.chainingMode=generic-veth --set cni.chainingTarget=k8s-pod-network --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set hubble.relay.enabled=true --set hubble.ui.enabled=true --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}"
# helm install cilium cilium/cilium --version 1.15.6 --namespace kube-system --set cni.chainingMode=generic-veth --set cni.chainingTarget=k8s-pod-network --set enableIPv4Masquerade=false --set enableIdentityMark=false --set routingMode=native --set hubble.relay.enabled=true --set hubble.ui.enabled=true --set prometheus.enabled=true --set operator.prometheus.enabled=true --set hubble.metrics.enableOpenMetrics=true --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http,port-distribution}" 

