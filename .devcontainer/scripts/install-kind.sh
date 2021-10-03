#! /bin/bash 
set -e
set -x

os=$(go env GOOS)
arch=$(go env GOARCH)
kind_version="v0.11.1"
# ref: https://kind.sigs.k8s.io/docs/user/quick-start/#installation

curl -Lo ./kind https://kind.sigs.k8s.io/dl/${kind_version}/kind-${os}-${arch}
chmod +x ./kind
mv ./kind /usr/local/bin/kind