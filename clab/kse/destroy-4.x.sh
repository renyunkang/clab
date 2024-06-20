#!/bin/bash
date
set -v

name="kse4"
kind delete cluster --name=${name}

rm  /root/.kube/config-4.0

sed -i '/# begin kind cluster-kse4/,/# end kind cluster-kse4/d' ~/.bash_aliases
