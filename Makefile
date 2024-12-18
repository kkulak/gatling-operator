
# Image URL to use all building/pushing image targets
IMAGE_TAG := $(shell /bin/date "+%Y%m%d-%H%M%S")
# Image URL should be like this when it gets to open sourced: ghcr.io/st-tech/gatling-operator:$(IMAGE_TAG)
IMG ?= gatling-operator:$(IMAGE_TAG)
# Image URL should be like this when it gets to open sourced: ghcr.io/st-tech/gatling:$(IMAGE_TAG)
SAMPLE_IMG := gatling:$(IMAGE_TAG)
# Release version
VERSION := latest
# Produce CRDs that work back to Kubernetes 1.11 (no version conversion)
CRD_OPTIONS ?= "crd:trivialVersions=true,preserveUnknownFields=false"
KIND_CLUSTER_NAME ?= "gatling-cluster"
K8S_NODE_IMAGE ?= v1.32.0
ENVTEST_K8S_VERSION ?= 1.30.0

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

# Setting SHELL to bash allows bash commands to be executed by recipes.
# This is a requirement for 'setup-envtest.sh' in the test target.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

KIND_CLUSTER_CONFIG_DIR=$(shell pwd)/config/kind
KUBECONFIG_BACKUP_DIR=$(shell pwd)/.kube

all: build

##@ General

# The help target prints out all targets with their descriptions organized
# beneath their categories. The categories are represented by '##@' and the
# target descriptions by '##'. The awk commands is responsible for reading the
# entire set of makefiles included in this invocation, looking for lines of the
# file as xyz: ## something, and then pretty-format the target and help. Then,
# if there's a line with ##@ something, that gets pretty-printed as a category.
# More info on the usage of ANSI control characters for terminal formatting:
# https://en.wikipedia.org/wiki/ANSI_escape_code#SGR_parameters
# More info on the awk command:
# http://linuxcommand.org/lc3_adv_awk.php

help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

kind-create: ## Create a kind cluster named ${KIND_CLUSTER_NAME} locally if necessary and save the kubectl config.
ifeq (1, $(shell kind get clusters | grep ${KIND_CLUSTER_NAME} | wc -l | tr -d ' '))
	@echo "Cluster already exists"
else
	@echo "Creating Cluster"
	kind create cluster --name ${KIND_CLUSTER_NAME} --image=kindest/node:${K8S_NODE_IMAGE} --config ${KIND_CLUSTER_CONFIG_DIR}/cluster.yaml
ifeq ($(IN_DEV_CONTAINER), true)
	@echo "kubeconfig backup =>"
	mkdir -p ${KUBECONFIG_BACKUP_DIR} && kind get kubeconfig --name ${KIND_CLUSTER_NAME} > ${KUBECONFIG_BACKUP_DIR}/kind-conifg.yaml
endif
endif

##@ Development

manifests: controller-gen ## Generate WebhookConfiguration, ClusterRole and CustomResourceDefinition objects.
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=manager-role webhook paths="./..." output:crd:artifacts:config=config/crd/bases

generate: controller-gen ## Generate code containing DeepCopy, DeepCopyInto, and DeepCopyObject method implementations.
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

manifests-release: manifests kustomize ## Generate all-in-one manifest for release
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default > gatling-operator.yaml

docs: crd-ref-docs ## Generate API reference documentation from CRD types
	cd config/crd-ref-docs
	$(CRD_REF_DOCS) --source-path=api --config=config/crd-ref-docs/config.yaml --renderer=markdown --templates-dir=config/crd-ref-docs/templates/markdown --output-path=docs/api.md

fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

test: manifests generate fmt vet setup-envtest ## Run tests.
	KUBEBUILDER_ASSETS="$(shell $(ENVTEST) use -p path $(ENVTEST_K8S_VERSION))" go test ./... -coverprofile cover.out

##@ Build

build: generate fmt vet ## Build manager binary.
	go build -o bin/manager main.go

run: manifests generate fmt vet ## Run a controller from your host.
	go run ./main.go

docker-build: test ## Build docker image with the manager.
	docker build -t ${IMG} .

docker-push: test ## Push docker image with the manager.
	docker buildx build --platform linux/amd64,linux/arm64 -t ${IMG} . --push

kind-load-image: kind-create docker-build ## Load local docker image into the kind cluster
	@echo "Loading image into kind"
	kind load docker-image ${IMG} --name ${KIND_CLUSTER_NAME} -v 1

kind-load-sample-image: kind-create sample-docker-build ## Load local docker image for sample Gatling into the kind cluster
	@echo "Loading sample image into kind"
	kind load docker-image ${SAMPLE_IMG} --name ${KIND_CLUSTER_NAME} -v 1

sample-docker-build: ## Build docker image for sample Gatling
	cd gatling && docker build -t ${SAMPLE_IMG} .

sample-docker-push: sample-docker-build ## Push docker image for sample Gatling
	docker push ${SAMPLE_IMG}

##@ Deployment

install-crd: manifests kustomize ## Install CRDs into the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl apply -f -

uninstall-crd: manifests kustomize ## Uninstall CRDs from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/crd | kubectl delete -f -

deploy: manifests kustomize ## Deploy controller to the K8s cluster specified in ~/.kube/config.
	cd config/manager && $(KUSTOMIZE) edit set image controller=${IMG}
	$(KUSTOMIZE) build config/default | kubectl apply -f -

kind-deploy: kind-load-image deploy ## Deploy controller to the kind cluster specified in ~/.kube/config.

sample-deploy: kustomize ## Install sample Gatling CR into the k8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/samples | sed -e "s,^\([[:space:]]*gatlingImage: \).*,\1${SAMPLE_IMG},g" | kubectl apply -f -

kind-sample-deploy: kind-load-sample-image sample-deploy ## Install sample Gatling CR into the kind cluster specified in ~/.kube/config.

undeploy: ## Undeploy controller from the K8s cluster specified in ~/.kube/config.
	$(KUSTOMIZE) build config/default | kubectl delete -f -

CONTROLLER_GEN = $(shell pwd)/bin/controller-gen
controller-gen: ## Download controller-gen locally if necessary.
	$(call go-install-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen@v0.14.0)

KUSTOMIZE = $(shell pwd)/bin/kustomize
kustomize: ## Download kustomize locally if necessary.
	$(call go-install-tool,$(KUSTOMIZE),sigs.k8s.io/kustomize/kustomize/v5@v5.3.0)

CRD_REF_DOCS = $(shell pwd)/bin/crd-ref-docs
crd-ref-docs: ## Download crd-ref-docs locally if necessary.
	$(call go-install-tool,$(CRD_REF_DOCS),github.com/elastic/crd-ref-docs@master)

ENVTEST = $(shell pwd)/bin/setup-envtest
setup-envtest: ## Download setup-envtest locally if necessary.
	$(call go-install-tool,$(ENVTEST),sigs.k8s.io/controller-runtime/tools/setup-envtest@latest)

# go-install-tool will 'go get' any package $2 and install it to $1.
PROJECT_DIR := $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST))))
define go-install-tool
@[ -f $(1) ] || { \
set -e ;\
TMP_DIR=$$(mktemp -d) ;\
cd $$TMP_DIR ;\
go mod init tmp ;\
echo "Downloading $(2)" ;\
GOBIN=$(PROJECT_DIR)/bin go install $(2) ;\
rm -rf $$TMP_DIR ;\
}
endef
