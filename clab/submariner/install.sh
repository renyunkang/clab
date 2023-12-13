export SERVER_IP="172.30.10.110"
binary_file="/usr/local/bin/subctl"

kind create cluster --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config - <<EOF
kind: Cluster
name: broker
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
networking:
  apiServerAddress: $SERVER_IP
  podSubnet: "10.7.0.0/16"
  serviceSubnet: "10.77.0.0/16"
EOF
cp ~/.kube/config ~/.kube/config-1

kind create cluster --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config - <<EOF
kind: Cluster
name: c1
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
networking:
  apiServerAddress: $SERVER_IP
  podSubnet: "10.8.0.0/16"
  serviceSubnet: "10.88.0.0/16"
EOF
cp ~/.kube/config ~/.kube/config-2

kind create cluster --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config - <<EOF
kind: Cluster
name: c2
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
networking:
  apiServerAddress: $SERVER_IP
  podSubnet: "10.9.0.0/16"
  serviceSubnet: "10.99.0.0/16"
EOF
cp ~/.kube/config ~/.kube/config-3

if [[ ! -x "$binary_file" ]]; then
  curl -Ls https://get.submariner.io | bash
  mv ~/.local/bin/subctl $binary_file
fi

# 添加内容到.bash_aliases文件
echo "# begin kind cluster-broker" >> ~/.bash_aliases
echo "alias k1='kubectl --kubeconfig=/root/.kube/config-1'" >> ~/.bash_aliases
echo "# end kind cluster-broker" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

# 添加内容到.bash_aliases文件
echo "# begin kind cluster-c1" >> ~/.bash_aliases
echo "alias k2='kubectl --kubeconfig=/root/.kube/config-2'" >> ~/.bash_aliases
echo "# end kind cluster-c1" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

# 添加内容到.bash_aliases文件
echo "# begin kind cluster-c2" >> ~/.bash_aliases
echo "alias k3='kubectl --kubeconfig=/root/.kube/config-3'" >> ~/.bash_aliases
echo "# end kind cluster-c2" >> ~/.bash_aliases
echo "" >> ~/.bash_aliases

source ~/.bashrc
