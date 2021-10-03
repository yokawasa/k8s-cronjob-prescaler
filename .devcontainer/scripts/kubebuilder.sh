#! /bin/bash 
set -e
set -x

os=$(go env GOOS)
arch=$(go env GOARCH)
kb_version="v3.1.0"

# download kubebuilder and extract it to tmp
curl -o /tmp/kubebuilder -sL https://github.com/kubernetes-sigs/kubebuilder/releases/download/${kb_version}/kubebuilder_${os}_${arch} 

# move to a long-term location and put it on your path
# (you'll need to set the KUBEBUILDER_ASSETS env var if you put it somewhere else)
chmod +x /tmp/kubebuilder
mkdir -p /usr/local/kubebuilder/bin
mv /tmp/kubebuilder /usr/local/kubebuilder/bin
export PATH=$PATH:/usr/local/kubebuilder/bin

# Clear down pkg file
rm -rf /go/pkg && rm -rf /go/src
