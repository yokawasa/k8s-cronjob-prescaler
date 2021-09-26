#! /bin/bash 
set -e
set -x

# Install helm 3.0
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | DESIRED_VERSION=v3.0.3 bash

# Add the stable chart repository
# ref: https://helm.sh/docs/intro/quickstart/ 
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update