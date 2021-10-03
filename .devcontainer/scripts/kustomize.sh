#! /bin/bash 
set -e
set -x

os=$(go env GOOS)
arch=$(go env GOARCH)
ks_version="v3.8.7"

# download kustomize
curl -o /tmp/kustomize.tar.gz -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${ks_version}/kustomize_${ks_version}_${os}_${arch}.tar.gz"
mkdir -p /usr/local/kubebuilder/bin
tar zxvf /tmp/kustomize.tar.gz -C /usr/local/kubebuilder/bin/

# set permission
chmod a+x /usr/local/kubebuilder/bin/kustomize
