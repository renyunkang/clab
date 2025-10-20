#!/bin/bash
date
set -v

#name="simple"
name="multus"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"

images=(calico/node:v3.26.1 calico/cni:v3.26.1 calico/kube-controllers:v3.26.1 rykren/netools:latest)

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.24.17@sha256:bad10f9b98d54586cba05a7eaa1b61c6b90bfc4ee174fdc43a7b75ca75c95e51 --config=-
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
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 172.31.50.22
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 172.31.50.23
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 172.31.50.24

networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

# 2.remove taints
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl get nodes -o wide

# 3.install CNI [Calico v3.26.1]
for i in "${images[@]}"
do
    docker pull $i
    kind load docker-image --name=${name} $i
done
kubectl apply -f ./calico.yaml
kubectl wait --timeout=100s --for=condition=Ready=true pods --all -A

# 4.deploy  clab
cat << EOF > clab.yaml | clab deploy --reconfigure -t clab.yaml -
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

    spine3:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config-spine3.cfg:/opt/vyatta/etc/config/config.boot

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

    leaf3:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config-leaf3.cfg:/opt/vyatta/etc/config/config.boot

#    route:
#      kind: linux
#      image: rykren/vyos:1.4
#      cmd: /sbin/init
#      binds:
#        - /lib/modules:/lib/modules
#        - vyos/config.cfg:/opt/vyatta/etc/config/config.boot

    server1:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${master}
      exec:
      - ip addr add 172.31.75.22/24 dev eth2
      - ip addr add 172.31.50.22/24 dev eth1
      - ip route replace default via 172.31.50.1
      - ip r add 172.32.60.0/24 via 172.31.75.1 dev eth2
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 192.168.10.2/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 192.168.10.1

    server2:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 172.31.75.23/24 dev eth2
      - ip addr add 172.31.50.23/24 dev eth1
      - ip route replace default via 172.31.50.1
      - ip r add 172.32.60.0/24 via 172.31.75.1 dev eth2
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 192.168.10.3/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 192.168.10.1

    server3:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 172.31.75.24/24 dev eth2
      - ip addr add 172.31.50.24/24 dev eth1
      - ip route replace default via 172.31.50.1
      - ip r add 172.32.60.0/24 via 172.31.75.1 dev eth2
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 192.168.10.4/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 192.168.10.1

#    server4:
#      kind: linux
#      image: rykren/netools:latest
#      exec:
#      - ip addr add 192.168.10.2/24 dev eth1
#      - ip route replace default via 192.168.10.1
#
#    server5:
#      kind: linux
#      image: rykren/netools:latest
#      exec:
#      - ip addr add 192.168.12.2/24 dev eth1
#      - ip route replace default via 192.168.12.1

    server6:
      kind: linux
      image: rykren/netools:latest
      exec:
      - ip addr add 172.32.60.2/24 dev eth1
      - ip route replace default via 172.32.60.1

  links:
  - endpoints: ["spine1:eth1", "leaf1:eth1"]
  - endpoints: ["leaf1:eth2", "server1:eth1"]
  - endpoints: ["leaf1:eth3", "server2:eth1"]
  - endpoints: ["leaf1:eth4", "server3:eth1"]
  - endpoints: ["spine2:eth2", "leaf2:eth1"]
  - endpoints: ["spine2:eth1", "spine3:eth1"]
  - endpoints: ["leaf2:eth2", "server1:eth2"]
  - endpoints: ["leaf2:eth3", "server2:eth2"]
  - endpoints: ["leaf2:eth4", "server3:eth2"]
  - endpoints: ["spine3:eth2", "leaf3:eth1"]
  - endpoints: ["leaf3:eth2", "server6:eth1"]
EOF

kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

# calico ipamconfig + kubelet maxPods 配置手动修改
#docker cp testdata/macvlan ${master}:/opt/cni/bin/
#docker cp calicoctl multus-control-plane:/usr/local/bin/

kubectl apply -f https://github.com/k8snetworkplumbingwg/whereabouts/blob/v0.9.2/doc/crds/daemonset-install.yaml
kubectl apply -f https://github.com/k8snetworkplumbingwg/whereabouts/blob/v0.9.2/doc/crds/whereabouts.cni.cncf.io_ippools.yaml
kubectl apply -f https://github.com/k8snetworkplumbingwg/whereabouts/blob/v0.9.2/doc/crds/whereabouts.cni.cncf.io_overlappingrangeipreservations.yaml


#kubectl apply \
#    -f doc/crds/daemonset-install.yaml \
#    -f doc/crds/whereabouts.cni.cncf.io_ippools.yaml \
#    -f doc/crds/whereabouts.cni.cncf.io_overlappingrangeipreservations.yaml
