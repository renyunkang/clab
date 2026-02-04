#!/bin/bash
date
set -v

name="bond"
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
- role: worker
- role: worker
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

cp /root/.kube/config /root/.kube/config-${name}

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
cat << EOF > clab-bond.yaml | clab deploy --reconfigure -t clab-bond.yaml -
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
        - vyos-bond/config.cfg:/opt/vyatta/etc/config/config.boot

    server1:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${master}

    server2:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node1}

    server3:
      kind: linux
      image: rykren/netools:latest
      network-mode: container:${node2}

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
  - endpoints: ["route:eth5", "server1:eth2"]
  - endpoints: ["route:eth6", "server2:eth2"]
  - endpoints: ["route:eth7", "server3:eth2"]
EOF

# install cni
# calico ipamconfig + kubelet maxPods 配置手动修改
docker cp calicoctl ${master}:/usr/local/bin/
docker cp calicoctl ${node1}:/usr/local/bin/
docker cp calicoctl ${node2}:/usr/local/bin/

helm repo add spiderpool https://spidernet-io.github.io/spiderpool
helm repo update spiderpool
helm install spiderpool spiderpool/spiderpool --namespace kube-system --set plugins.installCNI=true --kubeconfig=/root/.kube/config-${name}
#helm install spiderpool spiderpool/spiderpool --namespace kube-system --set multus.multusCNI.defaultCniCRName="macvlan-conf" --set plugins.installCNI=true --kubeconfig=/root/.kube/config-${name}

kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app.kubernetes.io/name=spiderpool' -A --kubeconfig=/root/.kube/config-${name}


docker cp ifacer ${master}:/opt/cni/bin/
docker cp ifacer ${node1}:/opt/cni/bin/
docker cp ifacer ${node2}:/opt/cni/bin/
