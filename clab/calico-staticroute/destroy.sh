#!/bin/bash
set -v

name="staticroute"
kind delete cluster --name=${name}
clab destroy -t clab.yaml
