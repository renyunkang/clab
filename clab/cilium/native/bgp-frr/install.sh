cilium install \
    --version v1.19.0 \
    --set ipam.mode=kubernetes \
    --set routingMode=native \
    --set ipv4NativeRoutingCIDR="10.0.0.0/8" \
    --set bgpControlPlane.enabled=true \
    --set k8s.requireIPv4PodCIDR=true

cilium status --wait
cilium config view | grep enable-bgp

docker exec -it clab-bgp-topo-tor0 vtysh -c 'show bgp ipv4 summary wide'
docker exec -it clab-bgp-topo-tor1 vtysh -c 'show bgp ipv4 summary wide'
