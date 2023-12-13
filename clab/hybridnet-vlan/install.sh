#!/bin/bash
date
set -v

name="hybridnet"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
networkPolicy=false
chartVersion=0.6.6
replicas=1
timeout=120s
vlanic="eth1"
vxlanic="eth1\.10"
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
        node-ip: 10.10.10.2 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.10.3 # 节点 IP
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.10.10.4 # 节点 IP
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  # podSubnet: 10.10.0.0/18
  serviceSubnet: 10.233.0.0/18
  kubeProxyMode: "ipvs"
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
    route:
      kind: linux
      image: rykren/vyos:1.4
      cmd: /sbin/init
      binds:
        - /lib/modules:/lib/modules
        - vyos/config.cfg:/opt/vyatta/etc/config/config.boot

    server1:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${master}
      exec:
      - ip addr add 10.10.10.2/24 dev eth1
      - ip route replace default via 10.10.10.1
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 10.10.10.2/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 10.10.10.1

    server2:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 10.10.10.3/24 dev eth1
      - ip route replace default via 10.10.10.1
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 10.10.10.3/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 10.10.10.1

    server3:
      kind: linux
      image: rykren/nettools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 10.10.10.4/24 dev eth1
      - ip route replace default via 10.10.10.1
      # - ip link add link eth1 name eth1.10 type vlan id 10
      # - ip addr add 10.10.10.4/24 dev eth1.10
      # - ip link set dev eth1.10 up
      # - ip route replace default via 10.10.10.1

    server4:
      kind: linux
      image: rykren/nettools:latest
      exec:
      - ip addr add 10.10.12.2/24 dev eth1
      - ip route replace default via 10.10.12.1
      # - ip link add link eth1 name eth1.12 type vlan id 12
      # - ip addr add 10.10.12.2/24 dev eth1.12
      # - ip link set dev eth1.12 up
      # - ip route replace default via 10.10.12.1

  links:
  - endpoints: ["route:eth1", "server1:eth1"]
  - endpoints: ["route:eth2", "server2:eth1"]
  - endpoints: ["route:eth3", "server3:eth1"]
  - endpoints: ["route:eth4", "server4:eth1"]
EOF

# 4. config cni
for i in "${images[@]}"
do
    docker pull $i
    kind load docker-image --name=${name} $i
done

helm repo add hybridnet https://alibaba.github.io/hybridnet/
helm repo update
helm install hybridnet hybridnet/hybridnet -n kube-system --set init.cidr=10.233.64.0/18 --set daemon.preferVlanInterfaces=${vlanic} --set daemon.preferVxlanInterfaces=${vxlanic} --set manager.replicas=${replicas} --set webhook.replicas=${replicas} --set typha.replicas=${replicas} --set daemon.enableNetworkPolicy=${networkPolicy} --set defaultNetworkType=Underlay --version ${chartVersion}
kubectl set image -n kube-system daemonset/hybridnet-daemon *="rykren/hybridnet:latest-amd64"


kubectl wait --timeout=${timeout} --for=condition=Ready=true pods --all -A



