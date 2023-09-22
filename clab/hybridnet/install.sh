#!/bin/bash
date
set -v

name="hybridnet"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
node3="${name}-worker3"
node4="${name}-worker4"
node5="${name}-worker5"
node6="${name}-worker6"
node7="${name}-worker7"
node8="${name}-worker8"
node9="${name}-worker9"
networkPolicy=false
chartVersion=0.6.6
replicas=1
timeout=120s
vlanic="eth1"
vxlanic="eth1\.10\,eth1\.11\,eth1\.21\,eth1\.22\,eth1"
images=(hybridnetdev/hybridnet:v0.8.6 rykren/hybridnet:latest-amd64 rykren/netools:latest)
k8simages="kindest/node:v1.23.13@sha256:ef453bb7c79f0e3caba88d2067d4196f427794086a7d0df8df4f019d5e336b61"
#k8simages="kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315"

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=${k8simages} --config=-
kind: Cluster
name: hybridnet
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.0.2 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.0.3 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.0.4 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.10.2 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.11.2 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.11.20.2 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.11.20.3 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.11.21.2 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.11.22.2 # 节点 IP
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF


# 2.remove taints
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl label $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master=""
kubectl get nodes -o wide

# 3.deploy  clab
cat << EOF > clab.yaml | clab deploy --reconfigure -t clab.yaml -
name: hybirdnet
mgmt:
  network: clab
  bridge: clab
  ipv4-subnet: 172.30.30.0/24 # ip range for the docker network
  ipv4-gw: 172.30.30.1 # set custom gateway ip
topology:
  nodes:
    spine1:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config-spine1.cfg:/opt/vyatta/etc/config/config.boot

    spine2:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config-spine2.cfg:/opt/vyatta/etc/config/config.boot

    leaf1:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config-leaf1.cfg:/opt/vyatta/etc/config/config.boot

    leaf2:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config-leaf2.cfg:/opt/vyatta/etc/config/config.boot

    server1:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${master}
      exec:
      - ip addr add 10.10.0.2/24 dev eth1
      - ip route replace default via 10.10.0.1

    server2:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 10.10.0.3/24 dev eth1
      - ip route replace default via 10.10.0.1

    server3:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 10.10.0.4/24 dev eth1
      - ip route replace default via 10.10.0.1

    server4:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node3}
      exec:
      - ip addr add 10.10.10.2/24 dev eth1
      - ip route replace default via 10.10.10.1
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 10.10.10.2/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 10.10.10.1

    server5:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node4}
      exec:
      - ip addr add 10.10.11.2/24 dev eth1
      - ip route replace default via 10.10.11.1
      # - ip link add link eth1 name eth1.11 type vlan id 11
      # - ip addr add 10.10.11.2/24 dev eth1.11
      # - ip link set dev eth1.11 up
      # - ip route replace default via 10.10.11.1

    server11:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node5}
      exec:
      - ip addr add 10.11.20.2/24 dev eth1
      - ip route replace default via 10.11.20.1

    server12:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node6}
      exec:
      - ip addr add 10.11.20.3/24 dev eth1
      - ip route replace default via 10.11.20.1

    server13:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node7}
      exec:
      - ip addr add 10.11.21.2/24 dev eth1
      - ip route replace default via 10.11.21.2
      # - ip link add link eth1 name eth1.21 type vlan id 21
      # - ip addr add 10.11.21.2/24 dev eth1.21
      # - ip link set dev eth1.21 up
      # - ip route replace default via 10.11.21.1

    server14:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node8}
      exec:
      - ip addr add 10.11.22.2/24 dev eth1
      - ip route replace default via 10.11.22.1
      # - ip link add link eth1 name eth1.22 type vlan id 22
      # - ip addr add 10.11.22.2/24 dev eth1.22
      # - ip link set dev eth1.22 up
      # - ip route replace default via 10.11.22.1

    server15:
      kind: linux
      image: rykren/nettools:latest
      exec:
      - ip addr add 10.11.20.4/24 dev eth1
      - ip route replace default via 10.11.20.1

  links:
  - endpoints: ["leaf1:eth1", "spine1:eth1"]
  - endpoints: ["leaf1:eth2", "spine2:eth1"]
  - endpoints: ["leaf2:eth1", "spine1:eth2"]
  - endpoints: ["leaf2:eth2", "spine2:eth2"]

  - endpoints: ["leaf1:eth11", "server1:eth1"]
  - endpoints: ["leaf1:eth12", "server2:eth1"]
  - endpoints: ["leaf1:eth13", "server3:eth1"]
  - endpoints: ["leaf1:eth14", "server4:eth1"]
  - endpoints: ["leaf1:eth15", "server5:eth1"]

  - endpoints: ["leaf2:eth11", "server11:eth1"]
  - endpoints: ["leaf2:eth12", "server12:eth1"]
  - endpoints: ["leaf2:eth13", "server13:eth1"]
  - endpoints: ["leaf2:eth14", "server14:eth1"]
  - endpoints: ["leaf2:eth15", "server15:eth1"]
EOF

# 4. config cni
for i in "${images[@]}"
do
    docker pull $i
    kind load docker-image --name=${name} $i
done

helm repo add hybridnet https://alibaba.github.io/hybridnet/
helm repo update
helm install hybridnet hybridnet/hybridnet -n kube-system --set init.cidr=10.233.64.0/18 --set daemon.preferVlanInterfaces=${vlanic} --set daemon.preferVxlanInterfaces=${vxlanic} --set manager.replicas=${replicas} --set webhook.replicas=${replicas} --set typha.replicas=${replicas} --set daemon.enableNetworkPolicy=${networkPolicy} --version ${chartVersion}
kubectl set image -n kube-system daemonset/hybridnet-daemon *="rykren/hybridnet:latest-amd64"


kubectl wait --timeout=${timeout} --for=condition=Ready=true pods --all -A



