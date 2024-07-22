#!/bin/bash
set -v

name="calico-hubble"
kind delete cluster --name=${name}
rm -r /root/.kube/config-${name}
