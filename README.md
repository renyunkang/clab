# clab
 more clab examples -> : https://github.com/srl-labs/containerlab/tree/main/lab-examples

For more convenient command operations, you can create the following command aliases:
```bash 
cat .bash_aliases 
alias clab='containerlab'
alias knode1-exec='docker exec -it cluster-control-plane bash'
alias knode2-exec='docker exec -it cluster-worker bash'
alias knode3-exec='docker exec -it cluster-worker2 bash'
alias knode4-exec='docker exec -it cluster-worker3 bash'
alias node1-exec='docker exec -it clab-bgp-server1 bash'
alias node2-exec='docker exec -it clab-bgp-server2 bash'
alias node3-exec='docker exec -it clab-bgp-server3 bash'
alias node4-exec='docker exec -it clab-bgp-server4 bash'
alias spine1-exec='docker exec -it clab-bgp-spine1 bash'
alias spine2-exec='docker exec -it clab-bgp-spine2 bash'
alias leaf1-exec='docker exec -it clab-bgp-leaf1 bash'
alias leaf2-exec='docker exec -it clab-bgp-leaf2 bash'
alias vspine1-exec='docker exec -it clab-bgp-spine1 su vyos'
alias vspine2-exec='docker exec -it clab-bgp-spine2 su vyos'
alias vleaf1-exec='docker exec -it clab-bgp-leaf1 su vyos'
alias vleaf2-exec='docker exec -it clab-bgp-leaf2 su vyos'
```


### Required tools
#### kind
https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries
```
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

#### containerlab
```
bash -c "$(curl -sL https://get.containerlab.dev)"
```

#### kubectl
https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#install-kubectl-binary-with-curl-on-linux
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```
