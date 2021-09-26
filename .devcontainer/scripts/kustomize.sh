#! /bin/bash 
set -e
set -x

# download kustomize
curl -o /tmp/kustomize.tar.gz -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv3.8.7/kustomize_v3.8.7_linux_amd64.tar.gz"
tar zxvf /tmp/kustomize.tar.gz -C /usr/local/kubebuilder/bin/ 

# set permission
chmod a+x /usr/local/kubebuilder/bin/kustomize
