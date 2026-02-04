#!/bin/bash
date
set -v

#name="simple"
name="mul-single"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"

images=(rykren/netools:latest)

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.24.17@sha256:bad10f9b98d54586cba05a7eaa1b61c6b90bfc4ee174fdc43a7b75ca75c95e51 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker

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

# kubectl apply -f ./calico.yaml
# kubectl wait --timeout=100s --for=condition=Ready=true pods --all -A

helm repo add cilium https://helm.cilium.io/
# helm install cilium cilium/cilium --namespace kube-system --version 1.13.11 --set bpf.vlanBypass={0} --set cni.exclusive=false
helm install cilium cilium/cilium --namespace kube-system --version 1.14.11 --set bpf.vlanBypass={0}
kubectl wait --for=condition=ready -l k8s-app=cilium pod -n kube-system


# 4.deploy  clab
cat << EOF > clab-single.yaml | clab deploy --reconfigure -t clab-single.yaml -
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
        - vyos-single-route/config.cfg:/opt/vyatta/etc/config/config.boot

    server1:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${master}
      exec:
      - ip link add link eth1 name eth1.73 type vlan id 73
      - ip link add link eth1 name eth1.74 type vlan id 74
      - ip link add link eth1 name eth1.75 type vlan id 75
      - ip link add link eth1 name eth1.50 type vlan id 50
      - ip link set dev eth1.50 up
      - ip link set dev eth1.73 up
      - ip link set dev eth1.74 up
      - ip link set dev eth1.75 up
      - ip addr add 172.31.50.22/24 dev eth1.50
      - ip addr add 172.31.75.22/24 dev eth1.75
      # - ip route replace default via 172.31.50.1

    server2:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node1}
      exec:
      - ip link add link eth1 name eth1.73 type vlan id 73
      - ip link add link eth1 name eth1.74 type vlan id 74
      - ip link add link eth1 name eth1.75 type vlan id 75
      # - ip link add link eth1 name eth1.50 type vlan id 50
      # - ip link set dev eth1.50 up
      - ip link set dev eth1.73 up
      - ip link set dev eth1.74 up
      - ip link set dev eth1.75 up
      # - ip addr add 172.31.50.23/24 dev eth1.50
      - ip addr add 172.31.50.23/24 dev eth1
      - ip addr add 172.31.75.23/24 dev eth1.75
      # - ip route replace default via 172.31.50.1

    server3:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node2}
      exec:
      - ip link add link eth1 name eth1.73 type vlan id 73
      - ip link add link eth1 name eth1.74 type vlan id 74
      - ip link add link eth1 name eth1.75 type vlan id 75
      - ip link add link eth1 name eth1.50 type vlan id 50
      - ip link set dev eth1.50 up
      - ip link set dev eth1.73 up
      - ip link set dev eth1.74 up
      - ip link set dev eth1.75 up
      - ip addr add 172.31.50.24/24 dev eth1.50
      - ip addr add 172.31.75.24/24 dev eth1.75
      # - ip route replace default via 172.31.50.1

    server4:
      kind: linux
      image: rykren/netools:latest
      exec:
      - ip addr add 172.31.50.50/24 dev eth1
      - ip route replace default via 172.31.50.1

  links:
  - endpoints: ["route:eth1", "server1:eth1"]
  - endpoints: ["route:eth2", "server2:eth1"]
  - endpoints: ["route:eth3", "server3:eth1"]
  - endpoints: ["route:eth4", "server4:eth1"]
EOF

# install multus-cni
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

# install macvlan
# calico ipamconfig + kubelet maxPods 配置手动修改
docker cp cni-plugins/macvlan ${master}:/opt/cni/bin/
docker cp cni-plugins/macvlan ${node1}:/opt/cni/bin/
docker cp cni-plugins/macvlan ${node2}:/opt/cni/bin/
docker cp cni-plugins/ipvlan ${master}:/opt/cni/bin/
docker cp cni-plugins/ipvlan ${node1}:/opt/cni/bin/
docker cp cni-plugins/ipvlan ${node2}:/opt/cni/bin/

# install whereabouts
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/whereabouts/refs/tags/v0.9.2/doc/crds/daemonset-install.yaml
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/whereabouts/refs/tags/v0.9.2/doc/crds/whereabouts.cni.cncf.io_ippools.yaml
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/whereabouts/refs/tags/v0.9.2/doc/crds/whereabouts.cni.cncf.io_overlappingrangeipreservations.yaml


