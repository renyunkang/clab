#!/bin/bash
date
set -v

name="spiderpool"
kind delete cluster --name=${name}

rm  /root/.kube/config-${name}

sed -i '/# begin kind cluster-${name}/,/# end kind cluster-${name}/d' ~/.bash_aliases
