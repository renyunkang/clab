#!/bin/bash
date
set -v

name="calico-rr"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
node3="${name}-worker3"
LB=${LB:-false}
pathDir="vyos-calico"
if [ "$LB" = true ]; then
    echo "use lb config ..."
    pathDir="vyos-calico-lb"
fi
images=(calico/node:v3.26.1 calico/cni:v3.26.1 calico/kube-controllers:v3.26.1 rykren/netools:latest)

# 1.prep no cni - cluster env
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
  - containerPort: 30881
    hostPort: 30881
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30882
    hostPort: 30882
    listenAddress: "0.0.0.0"
    protocol: tcp
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.5.11
        node-labels: "rack=rack1"

- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.5.12
        node-labels: "rack=rack1"

- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.8.13
        node-labels: "rack=rack2"

- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.8.14
        node-labels: "rack=rack2"

networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

# 2.remove taints
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl get nodes -o wide

# 3.deploy  clab
cat <<EOF>clab.yaml | clab deploy --reconfigure -t clab.yaml -
name: calico-rr
mgmt:
  network: clab
  bridge: clab
  ipv4-subnet: 172.30.30.0/24 # ip range for the docker network
  ipv4-gw: 172.30.30.1 # set custom gateway ip
topology:
  nodes:
    spine1:
      kind: linux
      image: unibaktr/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - ${pathDir}/config-spine1.cfg:/opt/vyatta/etc/config/config.boot

    spine2:
      kind: linux
      image: unibaktr/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - ${pathDir}/config-spine2.cfg:/opt/vyatta/etc/config/config.boot

    leaf1:
      kind: linux
      image: unibaktr/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - ${pathDir}/config-leaf1.cfg:/opt/vyatta/etc/config/config.boot

    leaf2: 
      kind: linux
      image: unibaktr/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - ${pathDir}/config-leaf2.cfg:/opt/vyatta/etc/config/config.boot


    server1:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${master}
      exec:
      - ip addr add 10.1.5.11/24 dev net0
      - ip route replace default via 10.1.5.1
    server2:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 10.1.5.12/24 dev net0
      - ip route replace default via 10.1.5.1

    server3:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 10.1.8.13/24 dev net0
      - ip route replace default via 10.1.8.1

    server4:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node3}
      exec:
      - ip addr add 10.1.8.14/24 dev net0
      - ip route replace default via 10.1.8.1

    server5:
      kind: linux
      image: rykren/nettools:latest
      exec:
      - ip addr add 10.1.8.15/24 dev net0
      - ip route replace default via 10.1.8.1
  links:
  - endpoints: ["leaf1:eth1", "spine1:eth1"]
  - endpoints: ["leaf1:eth2", "spine2:eth1"]
  - endpoints: ["leaf1:eth3", "server1:net0"]
  - endpoints: ["leaf1:eth4", "server2:net0"]

  - endpoints: ["leaf2:eth1", "spine1:eth2"]
  - endpoints: ["leaf2:eth2", "spine2:eth2"]
  - endpoints: ["leaf2:eth3", "server3:net0"]
  - endpoints: ["leaf2:eth4", "server4:net0"]
  - endpoints: ["leaf2:eth5", "server5:net0"]

EOF

# 4. config cni
# 4.1 install CNI[Calico v3.23.2]
# 4. config cni
for i in "${images[@]}"
do
    docker pull $i
    kind load docker-image --name=${name} $i
done
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
calicoctl --allow-version-mismatch patch node ${master} --patch '{"spec": {"bgp": {"asNumber": "65005"}}}'
calicoctl --allow-version-mismatch patch node ${node1} --patch '{"spec": {"bgp": {"asNumber": "65005"}}}'
calicoctl --allow-version-mismatch patch node ${node2} --patch '{"spec": {"bgp": {"asNumber": "65008"}}}'
calicoctl --allow-version-mismatch patch node ${node3} --patch '{"spec": {"bgp": {"asNumber": "65008"}}}'

# 4.4. peer to leaf switch
cat <<EOF | calicoctl --allow-version-mismatch apply -f -
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: rack1-to-leaf1
spec:
  peerIP: 10.1.5.1
  asNumber: 65005
  nodeSelector: rack == 'rack1'
---
apiVersion: projectcalico.org/v3
kind: BGPPeer
metadata:
  name: rack2-to-leaf2
spec:
  peerIP: 10.1.8.1
  asNumber: 65008
  nodeSelector: rack == 'rack2'
EOF


