#!/bin/bash
date
set -v

name="test"
kind delete cluster --name=${name}

rm  /root/.kube/config-test

sed -i '/# begin kind cluster-test/,/# end kind cluster-test/d' ~/.bash_aliases
