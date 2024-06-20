#!/bin/bash
date
set -v

name3="kse3"
name4="kse4"
kind delete cluster --name=${name3}
kind delete cluster --name=${name4}

rm  /root/.kube/config-3.5
rm  /root/.kube/config-4.0

sed -i '/# begin kind cluster-${name3}/,/# end kind cluster-${name3}/d' ~/.bash_aliases
sed -i '/# begin kind cluster-${name4}/,/# end kind cluster-${name4}/d' ~/.bash_aliases

