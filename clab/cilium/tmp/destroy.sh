#!/bin/bash
set -v

name1="cil-native"
name2="cil-tunnel"
name3="cil-eproute"

kind delete cluster --name=${name1}
rm -r /root/.kube/config-${name1}

kind delete cluster --name=${name2}
rm -r /root/.kube/config-${name2}

kind delete cluster --name=${name3}
rm -r /root/.kube/config-${name3}
