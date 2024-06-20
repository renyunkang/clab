#!/bin/bash
date
set -v

#name="simple"
name="openelb-secip"
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
        node-ip: 192.168.0.2
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.3
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 192.168.0.4

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
    route:
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
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 192.168.10.2/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 192.168.10.1

    server2:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 192.168.0.3/24 dev eth1
      - ip route replace default via 192.168.0.1
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 192.168.10.3/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 192.168.10.1

    server3:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 192.168.0.4/24 dev eth1
      - ip route replace default via 192.168.0.1
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 192.168.10.4/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 192.168.10.1

    server4:
      kind: linux
      image: rykren/netools:latest
      exec:
      - ip addr add 192.168.10.2/24 dev eth1
      - ip route replace default via 192.168.10.1

    server5:
      kind: linux
      image: rykren/netools:latest
      exec:
      - ip addr add 192.168.12.2/24 dev eth1
      - ip route replace default via 192.168.12.1
  links:
  - endpoints: ["route:eth1", "server1:eth1"]
  - endpoints: ["route:eth2", "server2:eth1"]
  - endpoints: ["route:eth3", "server3:eth1"]
  - endpoints: ["route:eth4", "server4:eth1"]
  - endpoints: ["route:eth5", "server5:eth1"]
EOF

# 5.install openelb
kubectl apply -f https://raw.githubusercontent.com/renyunkang/openelb/master/deploy/openelb.yaml
kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app=openelb-controller' -A
kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app=openelb' -A

# 6.config service
kubectl apply -f ./testdata/eip.yaml
kubectl apply -f ./testdata/deploy.yaml
