#!/bin/bash
date
set -v

name="multiple"
master="${name}-control-plane"
node1="${name}-worker"
node2="${name}-worker2"
node3="${name}-worker3"
images=(calico/node:v3.26.1 calico/cni:v3.26.1 calico/kube-controllers:v3.26.1 rykren/netools:latest rykren/openelb-controller:refactor rykren/openelb-speaker:refactor kubespheredev/kube-webhook-certgen:v1.1.1 kubesphere/kube-keepalived-vip:0.35)

# 1.prep no cni - cluster env
cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 30880
    hostPort: 31880
    listenAddress: "0.0.0.0"
    protocol: tcp
  - containerPort: 30881
    hostPort: 31881
    listenAddress: "0.0.0.0"
    protocol: tcp
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.5.11
        node-labels: "openelb.kubesphere.io/rack=leaf1"

- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.5.12
        node-labels: "openelb.kubesphere.io/rack=leaf1"

- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.8.13
        node-labels: "openelb.kubesphere.io/rack=leaf2"

- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-ip: 10.1.8.14
        node-labels: "openelb.kubesphere.io/rack=leaf2"

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
      image: rykren/netools:latest
      network-mode: container:${master}
      exec:
      - ip addr add 10.1.5.11/24 dev net0
      - ip route replace default via 10.1.5.1
    server2:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node1}
      exec:
      - ip addr add 10.1.5.12/24 dev net0
      - ip route replace default via 10.1.5.1
    server3:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node2}
      exec:
      - ip addr add 10.1.8.13/24 dev net0
      - ip route replace default via 10.1.8.1
    server4:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node3}
      exec:
      - ip addr add 10.1.8.14/24 dev net0
      - ip route replace default via 10.1.8.1

    client:
      kind: linux
      image: rykren/netools:latest
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
  - endpoints: ["leaf2:eth5", "client:net0"]

EOF


# 5.install openelb
kubectl apply -f ./openelb.yaml
kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app=openelb-controller' -A
kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app=openelb' -A

# 6.config bgp
kubectl apply -f ./openelb-bgp.yaml

sleep 2
kubectl apply -f ./testdata/bgp-eip.yaml
kubectl apply -f ./testdata/deploy.yaml

sleep 2
kubectl get deploy,eip,svc
docker exec -it clab-${name}-client bash
