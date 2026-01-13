#!/bin/bash
date
set -v

name="spiderpool"
#images=(ghcr.io/spidernet-io/spiderpool/spiderpool-controller:v0.9.3 ghcr.io/spidernet-io/spiderpool/spiderpool-agent:v0.9.3 ghcr.io/spidernet-io/spiderpool/spiderpool-plugins:v0.9.2 ghcr.io/k8snetworkplumbingwg/multus-cni:v3.9.3)
MACVLAN_MASTER_INTERFACE="eth0"
NUM_WORKERS=1
DATA_DIR="/opt/cni/bin/"

worker_nodes=""
for ((i=1; i<=NUM_WORKERS; i++))
do
  worker_nodes="$worker_nodes
- role: worker"
done

cat <<EOF | kind create cluster --name=${name} --image=kindest/node:v1.27.10 --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
$worker_nodes
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF

cp /root/.kube/config /root/.kube/config-${name}

# 2.remove taints
controller_node_ip=`kubectl get node -o wide --no-headers | grep -E "control-plane|bpf1" | awk -F " " '{print $6}'`
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/master:NoSchedule-
kubectl taint nodes $(kubectl get nodes -o name | grep control-plane) node-role.kubernetes.io/control-plane:NoSchedule-
kubectl get nodes -o wide


# install cni
kubectl apply -f ./calico.yaml

for i in "${images[@]}"
do
    docker pull $i
    kind load docker-image --name=${name} $i
done

helm repo add spiderpool https://spidernet-io.github.io/spiderpool
helm repo update spiderpool
helm install spiderpool spiderpool/spiderpool --namespace kube-system --kubeconfig=/root/.kube/config-${name}
#helm install spiderpool spiderpool/spiderpool --namespace kube-system --set multus.multusCNI.defaultCniCRName="macvlan-conf" --set plugins.installCNI=true --kubeconfig=/root/.kube/config-${name}

kubectl wait --timeout=100s --for=condition=Ready=true pods -l 'app.kubernetes.io/name=spiderpool' -A --kubeconfig=/root/.kube/config-${name}

echo "# begin kind cluster-${name}" >> ~/.bash_aliases
echo "alias kubectl-${name}='kubectl --kubeconfig=/root/.kube/config-4.0'" >> ~/.bash_aliases
echo "# end kind cluster-${name}" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

source ~/.bashrc
