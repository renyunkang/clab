#!/bin/bash
date
set -v

name="staticroute"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
k8simages="kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315"

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=${k8simages} --config=-
kind: Cluster
name: ${name}
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.2 # 节点 IP
        node-labels: "nodeName=master"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.3 # 节点 IP
        node-labels: "nodeName=worker1"
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.4 # 节点 IP
        node-labels: "nodeName=worker2"
networking:
  kubeProxyMode: "ipvs"
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF


# 2.remove taints
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl label $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master=""
kubectl get nodes -o wide

# 3.deploy clab and run bird node
cat << EOF > clab.yaml | clab deploy --reconfigure -t clab.yaml -
name: ${name}
mgmt:
  network: clab
  bridge: clab
  ipv4-subnet: 172.30.30.0/24 # ip range for the docker network
  ipv4-gw: 172.30.30.1 # set custom gateway ip
topology:
  nodes:
    router:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config.cfg:/opt/vyatta/etc/config/config.boot

    server1:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${master}
      exec:
      - ip addr add 192.168.0.2/24 dev eth1
      - ip route replace default via 192.168.0.1

    server2:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 192.168.0.3/24 dev eth1
      - ip route replace default via 192.168.0.1

    server3:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 192.168.0.4/24 dev eth1
      - ip route replace default via 192.168.0.1

    server4:
      kind: linux
      image: rykren/netools:latest
      exec:
      - ip addr add 192.168.0.5/24 dev eth1
      - ip route replace default via 192.168.0.1

  links:
  - endpoints: ["router:eth1", "server1:eth1"]
  - endpoints: ["router:eth2", "server2:eth1"]
  - endpoints: ["router:eth3", "server3:eth1"]
  - endpoints: ["router:eth4", "server4:eth1"]
EOF

# 4.config cni and load images
kind load docker-image --name=${name} rykren/whoami:latest
kind load docker-image --name=${name} calico/node:v3.26.1
kind load docker-image --name=${name} calico/kube-controllers:v3.26.1
kind load docker-image --name=${name} calico/cni:v3.26.1
kubectl apply -f ./calico-not-all.yaml


