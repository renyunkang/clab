#!/bin/bash
date
set -v

name="noderr"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
k8simages="kindest/node:v1.24.17@sha256:bad10f9b98d54586cba05a7eaa1b61c6b90bfc4ee174fdc43a7b75ca75c95e51"

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
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.3 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.4 # 节点 IP
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

# 3.deploy clab and run bird node - #rykren/vyos:1.4
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
kind load docker-image --name=${name} rykren/netools:latest
kind load docker-image --name=${name} calico/node:v3.27.5
kind load docker-image --name=${name} calico/kube-controllers:v3.27.5
kind load docker-image --name=${name} calico/cni:v3.27.5
# kind load docker-image --name=${name} calico/node:v3.27.2
# kind load docker-image --name=${name} calico/kube-controllers:v3.27.2
# kind load docker-image --name=${name} calico/cni:v3.27.2
kubectl apply -f ./calico.yaml

kubectl wait --timeout=100s --for=condition=Ready=true pods --all -A

# 4.2. disable bgp fullmesh
cat <<EOF | calicoctl --allow-version-mismatch apply -f - 
apiVersion: projectcalico.org/v3
items:
- apiVersion: projectcalico.org/v3
  kind: BGPConfiguration
  metadata:
    name: default
  spec:
    logSeverityScreen: Info
    nodeToNodeMeshEnabled: false
kind: BGPConfigurationList
metadata:
EOF

# 4.3. add() bgp configuration for the nodes
calicoctl --allow-version-mismatch label nodes ${master} routeReflector=10.0.0.1 --overwrite
calicoctl --allow-version-mismatch patch node ${master} --patch '{"spec": {"bgp": {"asNumber": "64512", "routeReflectorClusterID": "10.0.0.1"}}}'
calicoctl --allow-version-mismatch patch node ${node1} --patch '{"spec": {"bgp": {"asNumber": "64512"}}}'
calicoctl --allow-version-mismatch patch node ${node2} --patch '{"spec": {"bgp": {"asNumber": "64512"}}}'
# 4.4. peer to leaf switch
cat <<EOF | calicoctl --allow-version-mismatch apply -f -
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: node-to-rr
spec:
  nodeSelector: "all()"
  peerSelector: "has(routeReflector)"
---
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: rr-to-leaf
spec:
  nodeSelector: "has(routeReflector)"
  peerIP: 192.168.0.1
  asNumber: 64510
  keepOriginalNextHop: true
EOF

