#!/bin/bash
date
set -v

name="openelb"
REPO=${REPO:-}
TAG=${TAG:-latest}
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
      binds: 
      - $(pwd)/bgpconf:/root
      exec:
      - ip addr add 192.168.0.5/24 dev eth1
      - ip route replace default via 192.168.0.1
      - bird -c /root/bird.conf

  links:
  - endpoints: ["router:eth1", "server1:eth1"]
  - endpoints: ["router:eth2", "server2:eth1"]
  - endpoints: ["router:eth3", "server3:eth1"]
  - endpoints: ["router:eth4", "server4:eth1"]
EOF
# docker run --name client -d --network=kind --ip=192.168.0.5 --privileged=true -v $(pwd)/bgpconf:/root/ rykren/netools:latest
# docker exec -it client bird -c /root/bird.conf

# 4.config cni and load images
kubectl apply -f ./calico.yaml
if [ -n "$LOAD" ]; then
    kind load docker-image --name=${name} ${REPO}/openelb-controller:${TAG}
    kind load docker-image --name=${name} ${REPO}/openelb-speaker:${TAG}
    kind load docker-image --name=${name} kubesphere/kube-keepalived-vip:0.35
    kind load docker-image --name=${name} rykren/whoami:latest
    kind load docker-image --name=${name} calico/node:v3.26.1
    kind load docker-image --name=${name} calico/pod2daemon-flexvol:v3.26.1
    kind load docker-image --name=${name} calico/kube-controllers:v3.26.1
    kind load docker-image --name=${name} calico/cni:v3.26.1
    kind load docker-image --name=${name} registry.k8s.io/ingress-nginx/kube-webhook-certgen:v1.1.1
fi

# 5.install openelb
kubectl apply -f ./openelb.yaml
kubectl set image -n openelb-system deployment/openelb-controller *="${REPO}/openelb-controller:${TAG}"
kubectl set image -n openelb-system daemonset/openelb-speaker *="${REPO}/openelb-speaker:${TAG}"
kubectl wait -n openelb-system --timeout=100s --for=condition=Available deployment/openelb-controller
#kubectl wait -n openelb-system --timeout=100s --for=condition=Available ds/openelb-speaker
sleep 10

kubectl apply -f bgp.yaml
kubectl apply -f deploy.yaml
sleep 10

# 6.show route
echo "you can run 'docker exec -it client birdcl -s /var/run/bird.ctl' to show more infos."
docker exec -it clab-${name}-server4 ip r
