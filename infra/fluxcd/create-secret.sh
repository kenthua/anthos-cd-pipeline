#!/bin/bash
kubectl create secret generic flux-git-deploy \
  --namespace=flux \
  --from-file=identity=$1
