# Image URL to use all building/pushing image targets
IMAGE_TAG := $(shell /bin/date "+%Y%m%d-%H%M%S")
# IMG ?= ghcr.io/yokawasa/k8s-cronjob-prescaler:$(IMAGE_TAG)
IMG ?= k8s-cronjob-prescaler:${IMAGE_TAG}
# IMG ?= ghcr.io/yokawasa/k8s-cronjob-prescaler-initcontainer:1
INIT_IMG ?= k8s-cronjob-prescaler-initcontainer:1
# release version
VERSION ?= ${IMAGE_TAG}

# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true"
KIND_CLUSTER_NAME ?= "psccontroller"
K8S_NODE_IMAGE ?= v1.21.1
PROMETHEUS_INSTANCE_NAME ?= prometheus-operator
CONFIG_MAP_NAME ?= initcontainer-configmap

OS := $(shell uname | tr '[A-Z]' '[a-z]')

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# CI
all: manager
build-run-ci: manager unit-tests deploy-kind kind-tests kind-long-tests

# DEPLOYING:
# - Kind
deploy-kind: kind-start kind-load kind-load-initcontainer deploy-cluster
# - Configured Kubernetes cluster in ~/.kube/config (could be KIND too)
deploy-cluster: manifests install-crds install-prometheus kustomize-deployment

install-prometheus:
ifneq (1, $(shell helm list | grep ${PROMETHEUS_INSTANCE_NAME} | wc -l))
	./deploy/prometheus-grafana/deploy-prometheus.sh
else
	@echo "Helm installation of the prometheus-operator already exists with name ${PROMETHEUS_INSTANCE_NAME}... skipping"
endif

kustomize-deployment: kustomize kubectl
	@echo "Kustomizing k8s resource files"
	gsed -i "/configMapGenerator/,/${CONFIG_MAP_NAME}/d" config/manager/kustomization.yaml
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	cd config/manager && $(KUSTOMIZE) edit add configmap ${CONFIG_MAP_NAME} --from-literal=initContainerImage=${INIT_IMG}
	@echo "Applying kustomizations"
	$(KUSTOMIZE) build config/default | $(KUBECTL) apply --validate=false -f -

kustomize-release: kustomize kubectl
	@echo "Kustomizing k8s resource files"
	gsed -i "/configMapGenerator/,/${CONFIG_MAP_NAME}/d" config/manager/kustomization.yaml
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	cd config/manager && $(KUSTOMIZE) edit add configmap ${CONFIG_MAP_NAME} --from-literal=initContainerImage=${INIT_IMG}
	@echo "Generating release yaml"
	$(KUSTOMIZE) build config/default > k8s-cronjob-prescaler-$(VERSION).yaml

kind-start:
ifeq (1, $(shell kind get clusters | grep ${KIND_CLUSTER_NAME} | wc -l | tr -d ' '))
	@echo "Cluster already exists" 
else
	@echo "Creating Cluster"	
	kind create cluster --name ${KIND_CLUSTER_NAME} --image=kindest/node:${K8S_NODE_IMAGE}
endif

kind-load: docker-build
	@echo "Loading image into kind"
	kind load docker-image ${IMG} --name ${KIND_CLUSTER_NAME} -v 1

kind-load-initcontainer: docker-build-initcontainer
	@echo "Loading initcontainer image into kind"	
	kind load docker-image ${INIT_IMG} --name ${KIND_CLUSTER_NAME} -v 1

# Run integration tests in KIND
kind-tests: 
	ginkgo --skip="LONG TEST:" --nodes 6 --race --randomizeAllSpecs --cover --trace --progress --coverprofile ../controllers.coverprofile ./controllers
	-kubectl delete prescaledcronjobs --all -n psc-system

kind-long-tests:
	ginkgo --focus="LONG TEST:" -nodes 6 --randomizeAllSpecs --trace --progress ./controllers
	-kubetl delete prescaledcronjobs --all -n psc-system

# Run unit tests and output in JUnit format
unit-tests: generate checks manifests go-junit-report
	go test controllers/utilities_test.go controllers/utilities.go -v -cover 2>&1 | tee TEST-utilities.txt
	go test controllers/structhash_test.go controllers/structhash.go -v -cover 2>&1 | tee TEST-structhash.txt
	cat TEST-utilities.txt | $(GO_JUNIT_REPORT) 2>&1 > TEST-utilities.xml
	cat TEST-structhash.txt | $(GO_JUNIT_REPORT) 2>&1 > TEST-structhash.xml

# Build manager binary
manager: generate checks
	go build -o bin/manager main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate checks manifests
	go run ./main.go

# Install CRDs into a cluster
install-crds: manifests kustomize kubectl
	$(KUSTOMIZE) build config/crd | $(KUBECTL) apply -f -

# Uninstall CRDs from a cluster
uninstall-crds: manifests kustomize kubectl
	$(KUSTOMIZE) build config/crd | $(KUBECTL) delete -f -

# SAMPLE YAMLs
# - Regular cronjob
recreate-sample-cron: kubectl
	-kubectl delete cronjob samplecron
	$(KUBECTL) apply -f ./config/samples/cron_sample.yaml
# - PrescaledCronJob
recreate-sample-psccron: kubectl
	-kubectl delete prescaledcronjob prescaledcronjob-sample -n psc-system
	-kubectl delete cronjob autogen-prescaledcronjob-sample -n psc-system
	$(KUBECTL) apply -f ./config/samples/psc_v1alpha1_prescaledcronjob.yaml
# - Regular cronjob with init container
recreate-sample-initcron: kubectl
	-kubectl delete cronjob sampleinitcron
	$(KUBECTL) apply -f ./config/samples/init_cron_sample.yaml

# UTILITY
# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

# Run go fmt against code
fmt:
	find . -name '*.go' | grep -v vendor | xargs gofmt -s -w
	
# Run linting
checks: golangci-lint
	GO111MODULE=on $(GOLANGCI_LINT) run

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile=./hack/boilerplate.go.txt paths="./..."

# Build the docker image
docker-build: unit-tests
	docker build . -t ${IMG}

# Push the docker image
docker-push: docker-build
	docker push ${IMG}

# Build the docker image for initcontainer
docker-build-initcontainer:
	docker build -t ${INIT_IMG} ./initcontainer

# Push the docker image for initcontainer
docker-push-initcontainer: docker-build-initcontainer
	docker push ${INIT_IMG}

CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1)

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

KUBECTL = $(shell pwd)/bin/kubectl
kubectl: ## Download kubectl locally if necessary.
	$(call curl-get-tool,$(KUBECTL),https://dl.k8s.io/release/v1.20.2/bin/${OS}/amd64/kubectl)

GOLANGCI_LINT = $(shell go env GOPATH)/bin/golangci-lint
golangci-lint: ## Download golangci-lint locally
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sed 's/tar -/tar --no-same-owner -/g' | sh -s -- -b $(shell go env GOPATH)/bin

GO_JUNIT_REPORT = $(shell pwd)/bin/go-junit-report
go-junit-report: ## Download go-junit-report locally
	$(call go-get-tool,$(GO_JUNIT_REPORT),github.com/jstemmer/go-junit-report@v0.9.1)

# go-get-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-get-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go get $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef

# curl-get-tool will 'curl' any package $2 and install it to $1.
define curl-get-tool
@[ -f $(1) ] || { \
set -e ;\
echo "Downloading $(2)" ;\
curl -o $(1) -L $(2) ;\
chmod +x $(1) ;\
}
endef
