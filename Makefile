# Image URL to use all building/pushing image targets
timestamp := $(shell /bin/date "+%Y%m%d-%H%M%S")
IMG ?= controller:$(timestamp)
INIT_IMG ?= initcontainer:1
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true"
KIND_CLUSTER_NAME ?= "psccontroller"
K8S_NODE_IMAGE ?= v1.21.1
PROMETHEUS_INSTANCE_NAME ?= prometheus-operator
CONFIG_MAP_NAME ?= initcontainer-configmap

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
deploy-kind: kind-start kind-load-img kind-load-initcontainer deploy-cluster
# - Configured Kubernetes cluster in ~/.kube/config (could be KIND too)
deploy-cluster: manifests install-crds install-prometheus kustomize-deployment

install-prometheus:
ifneq (1, $(shell helm list | grep ${PROMETHEUS_INSTANCE_NAME} | wc -l))
	./deploy/prometheus-grafana/deploy-prometheus.sh
else
	@echo "Helm installation of the prometheus-operator already exists with name ${PROMETHEUS_INSTANCE_NAME}... skipping"
endif

kustomize-deployment: kustomize
	@echo "Kustomizing k8s resource files"
	sed -i "/configMapGenerator/,/${CONFIG_MAP_NAME}/d" config/manager/kustomization.yaml
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	cd config/manager && $(KUSTOMIZE) edit add configmap ${CONFIG_MAP_NAME} --from-literal=initContainerImage=${INIT_IMG}
	@echo "Applying kustomizations"
	$(KUSTOMIZE) build config/default | kubectl apply --validate=false -f -

kind-start:
ifeq (1, $(shell kind get clusters | grep ${KIND_CLUSTER_NAME} | wc -l | tr -d ' '))
	@echo "Cluster already exists" 
else
	@echo "Creating Cluster"	
	kind create cluster --name ${KIND_CLUSTER_NAME} --image=kindest/node:${K8S_NODE_IMAGE}
endif

kind-load-img: docker-build
	@echo "Loading image into kind"
	kind load docker-image ${IMG} --name ${KIND_CLUSTER_NAME} -v 1

# Run integration tests in KIND
kind-tests: 
	ginkgo --skip="LONG TEST:" --nodes 6 --race --randomizeAllSpecs --cover --trace --progress --coverprofile ../controllers.coverprofile ./controllers
	-kubectl delete prescaledcronjobs --all -n psc-system

kind-long-tests:
	ginkgo --focus="LONG TEST:" -nodes 6 --randomizeAllSpecs --trace --progress ./controllers
	-kubetl delete prescaledcronjobs --all -n psc-system

# Run unit tests and output in JUnit format
unit-tests: generate checks manifests
	go test controllers/utilities_test.go controllers/utilities.go -v -cover 2>&1 | tee TEST-utilities.txt
	go test controllers/structhash_test.go controllers/structhash.go -v -cover 2>&1 | tee TEST-structhash.txt
	cat TEST-utilities.txt | go-junit-report 2>&1 > TEST-utilities.xml
	cat TEST-structhash.txt | go-junit-report 2>&1 > TEST-structhash.xml

# Build manager binary
manager: generate checks
	go build -o bin/manager main.go

# Run against the configured Kubernetes cluster in ~/.kube/config
run: generate checks manifests
	go run ./main.go

# Install CRDs into a cluster
install-crds: manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

# Uninstall CRDs from a cluster
uninstall-crds: manifests kustomize
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

# SAMPLE YAMLs
# - Regular cronjob
recreate-sample-cron:
	-kubectl delete cronjob samplecron
	kubectl apply -f ./config/samples/cron_sample.yaml
# - PrescaledCronJob
recreate-sample-psccron:
	-kubectl delete prescaledcronjob prescaledcronjob-sample -n psc-system
	-kubectl delete cronjob autogen-prescaledcronjob-sample -n psc-system
	kubectl apply -f ./config/samples/psc_v1alpha1_prescaledcronjob.yaml
# - Regular cronjob with init container
recreate-sample-initcron:
	-kubectl delete cronjob sampleinitcron
	kubectl apply -f ./config/samples/init_cron_sample.yaml
	
# INIT CONTAINER
docker-build-initcontainer:
	docker build -t ${INIT_IMG} ./initcontainer

docker-push-initcontainer:
	docker push ${INIT_IMG}

kind-load-initcontainer: docker-build-initcontainer
	@echo "Loading initcontainer image into kind"	
	kind load docker-image ${INIT_IMG} --name ${KIND_CLUSTER_NAME} -v 1

# UTILITY
# Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

# Run go fmt against code
fmt:
	find . -name '*.go' | grep -v vendor | xargs gofmt -s -w
	
# Run linting
checks:
	GO111MODULE=on golangci-lint run

# Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile=./hack/boilerplate.go.txt paths="./..."

# Build the docker image
docker-build: unit-tests
	docker build . -t ${IMG}

# Push the docker image
docker-push:
	docker push ${IMG}

CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-get-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.4.1)

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-get-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v3@v3.8.7)

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
