#!/bin/bash
set -v

name1="replace"

kind delete cluster --name=${name1}
rm -r /root/.kube/config-${name1}

