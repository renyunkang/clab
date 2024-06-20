#!/bin/bash
date
set -v
NUMBER=${NUMBER:-2}

for i in "${images[@]}"
do
    worker=''
done

kind create cluster --image=kindest/node:v1.24.7@sha256:577c630ce8e509131eab1aea12c022190978dd2f745aac5eb1fe65c0807eb315 --config - <<EOF
kind: Cluster
name: typha
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
${worker}
networking:
  disableDefaultCNI: true
  podSubnet: 10.233.64.0/18
  serviceSubnet: 10.233.0.0/18
EOF
cp ~/.kube/config ~/.kube/config-1


