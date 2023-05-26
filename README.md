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
