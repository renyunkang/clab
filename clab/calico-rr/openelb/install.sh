name="calico-rr"

kubectl apply -f https://raw.githubusercontent.com/openelb/openelb/master/deploy/openelb.yaml

kubectl apply -f bgp.yaml
kubectl apply -f bgp-peer-spine.yaml



