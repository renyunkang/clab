#!/bin/bash
date
set -v

name="cilium-bgp"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
node3="${name}-worker3"
pathDir="vyos-cilium"

k8simages="kindest/node:v1.31.14"

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=${k8simages} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      certSANs:
        - "localhost"
        - "127.0.0.1"
        - "10.1.5.11"
        - "172.31.19.33"
nodes:
- role: control-plane
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
  apiServerAddress: 172.31.19.33
  kubeProxyMode: "none"
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF


# 2.deploy  clab
cat <<EOF>clab.yaml | clab deploy --reconfigure -t clab.yaml -
name: ${name}
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
      - ip route add 10.1.8.0/24 via 10.1.5.1 dev net0
      # - ip route add 172.31.0.0/16 dev eth0
      # - ip route replace default via 10.1.5.1
    server2:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 10.1.5.12/24 dev net0
      - ip route add 10.1.8.0/24 via 10.1.5.1 dev net0
      # - ip route add 172.31.0.0/16 dev eth0
      # - ip route replace default via 10.1.5.1

    server3:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 10.1.8.13/24 dev net0
      - ip route add 10.1.5.0/24 via 10.1.8.1 dev net0
      # - ip route add 172.31.0.0/16 dev eth0
      # - ip route replace default via 10.1.8.1

    server4:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node3}
      exec:
      - ip addr add 10.1.8.14/24 dev net0
      - ip route add 10.1.5.0/24 via 10.1.8.1 dev net0
      # - ip route add 172.31.0.0/16 dev eth0
      # - ip route replace default via 10.1.8.1

    server5:
      kind: linux
      image: rykren/nettools:latest
      exec:
      - ip addr add 10.1.8.15/24 dev net0
      - ip route replace default via 10.1.8.1
      - ip route add 172.31.0.0/16 dev eth0

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

check_nodes_ready() {
  kubectl get nodes -o wide | awk '{print $6}' | grep -q '^<none>$'
  return $?
}

while check_nodes_ready; do
  echo "尚有节点的 INTERNAL-IP 为 none，等待中..."
  sleep 5  # 每 5 秒检查一次
done

# 3.remove taints
node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
# kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl get nodes -o wide

# 4. config cni
helm repo add cilium https://helm.cilium.io > /dev/null 2>&1
helm repo update > /dev/null 2>&1

helm install cilium cilium/cilium --namespace kube-system --set routingMode=native --set directRoutingSkipUnreachable=true --set autoDirectNodeRoutes=true --set ipv4NativeRoutingCIDR=10.233.64.0/18 --set bgpControlPlane.enabled=true --set ipam.mode=multi-pool --set bpf.masquerade=true --set ipam.operator.autoCreateCiliumPodIPPools.default.ipv4.cidrs='{10.233.64.0/20}' --set ipam.operator.autoCreateCiliumPodIPPools.default.ipv4.maskSize=24 --set kubeProxyReplacement=true --set k8sServiceHost=${node_ip} --set k8sServicePort=6443

kubectl wait --for=condition=ready -l k8s-app=cilium pod -n kube-system

#  peer to leaf switch
#cat <<EOF | kubectl apply -f -
#apiVersion: "cilium.io/v2alpha1"
#kind: CiliumBGPPeeringPolicy
#metadata:
#  name: rack1
#spec:
#  nodeSelector:
#    matchLabels:
#      rack: rack1
#  virtualRouters:
#  - localASN: 65005
#    exportPodCIDR: true
#    neighbors:
#    - peerAddress: "10.1.5.1/24"
#      peerASN: 65005
#---
#apiVersion: "cilium.io/v2alpha1"
#kind: CiliumBGPPeeringPolicy
#metadata:
#  name: rack2
#spec:
#  nodeSelector:
#    matchLabels:
#      rack: rack2
#  virtualRouters:
#  - localASN: 65008
#    exportPodCIDR: true
#    neighbors:
#    - peerAddress: "10.1.8.1/24"
#      peerASN: 65008
#EOF

kubectl wait --for=condition=ready -l k8s-app=cilium pod -n kube-system

cat <<EOF | kubectl apply -f -
apiVersion: cilium.io/v2
kind: CiliumBGPClusterConfig
metadata:
  name: cilium-bgp-rack1
spec:
  nodeSelector:
    matchLabels:
      rack: rack1
  bgpInstances:
  - name: "instance-65000"
    localASN: 65005
    peers:
    - name: "peer-leaf1"
      peerASN: 65005
      peerAddress: "10.1.5.1"
      peerConfigRef:
        name: "cilium-peer"
---
apiVersion: cilium.io/v2
kind: CiliumBGPClusterConfig
metadata:
  name: cilium-bgp-rack2
spec:
  nodeSelector:
    matchLabels:
      rack: rack2
  bgpInstances:
  - name: "instance-65000"
    localASN: 65008
    peers:
    - name: "peer-leaf2"
      peerASN: 65008
      peerAddress: "10.1.8.1"
      peerConfigRef:
        name: "cilium-peer"
---
apiVersion: cilium.io/v2
kind: CiliumBGPPeerConfig
metadata:
  name: cilium-peer
spec:
  timers:
    holdTimeSeconds: 90
    keepAliveTimeSeconds: 30
  ebgpMultihop: 4
  gracefulRestart:
    enabled: true
    restartTimeSeconds: 15
  families:
    - afi: ipv4
      safi: unicast
      advertisements:
        matchLabels:
          advertise: "bgp"
---
apiVersion: cilium.io/v2
kind: CiliumBGPAdvertisement
metadata:
  name: bgp-advertisements
  labels:
    advertise: bgp
spec:
  advertisements:
    - advertisementType: "PodCIDR"
      attributes:
        communities:
          standard: [ "65000:99" ]
        localPreference: 99
EOF
