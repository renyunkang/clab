#!/bin/bash
date
set -v

name="kse3"
kind delete cluster --name=${name}

rm  /root/.kube/config-3.5

sed -i '/# begin kind cluster-${name}/,/# end kind cluster-${name}/d' ~/.bash_aliases
