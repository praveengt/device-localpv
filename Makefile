# Copyright 2019-2020 The OpenEBS Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# list only csi source code directories
PACKAGES = $(shell go list ./... | grep -v 'vendor\|pkg/generated')

UNIT_TEST_PACKAGES = $(shell go list ./... | grep -v 'vendor\|pkg/generated\|tests')

# Lint our code. Reference: https://golang.org/cmd/vet/
VETARGS?=-asmdecl -atomic -bool -buildtags -copylocks -methods \
         -nilfunc -printf -rangeloops -shift -structtags -unsafeptr

# Tools required for different make
# targets or for development purposes
EXTERNAL_TOOLS=\
	golang.org/x/tools/cmd/cover \
	golang.org/x/lint/golint \
	github.com/axw/gocov/gocov \
	gopkg.in/matm/v1/gocov-html \
	github.com/onsi/ginkgo/ginkgo \
	github.com/onsi/gomega/...


# The images can be pushed to any docker/image registeries
# like docker hub, quay. The registries are specified in
# the `build/push` script.
#
# The images of a project or company can then be grouped
# or hosted under a unique organization key like `openebs`
#
# Each component (container) will be pushed to a unique
# repository under an organization.
# Putting all this together, an unique uri for a given
# image comprises of:
#   <registry url>/<image org>/<image repo>:<image-tag>
#
# IMAGE_ORG can be used to customize the organization
# under which images should be pushed.
# By default the organization name is `openebs`.

ifeq (${IMAGE_ORG}, )
  IMAGE_ORG="openebs"
  export IMAGE_ORG
endif

# Specify the date of build
DBUILD_DATE=$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# Specify the docker arg for repository url
ifeq (${DBUILD_REPO_URL}, )
  DBUILD_REPO_URL="https://github.com/openebs/device-localpv"
  export DBUILD_REPO_URL
endif

# Specify the docker arg for website url
ifeq (${DBUILD_SITE_URL}, )
  DBUILD_SITE_URL="https://openebs.io"
  export DBUILD_SITE_URL
endif


ifeq (${IMAGE_TAG}, )
  IMAGE_TAG = ci
  export IMAGE_TAG
endif

# Determine the arch/os
ifeq (${XC_OS}, )
  XC_OS:=$(shell go env GOOS)
endif
export XC_OS
ifeq (${XC_ARCH}, )
  XC_ARCH:=$(shell go env GOARCH)
endif
export XC_ARCH
ARCH:=${XC_OS}_${XC_ARCH}
export ARCH

export DBUILD_ARGS=--build-arg DBUILD_DATE=${DBUILD_DATE} --build-arg DBUILD_REPO_URL=${DBUILD_REPO_URL} --build-arg DBUILD_SITE_URL=${DBUILD_SITE_URL} --build-arg BRANCH=${BRANCH} --build-arg RELEASE_TAG=${RELEASE_TAG}

# Specify the name for the binary
CSI_DRIVER=device-driver

.PHONY: all
all: license-check golint test manifests device-driver-image

.PHONY: clean
clean:
	@echo "--> Cleaning Directory" ;
	go clean -testcache
	rm -rf bin
	rm -rf ${GOPATH}/bin/${CSI_DRIVER}
	rm -rf ${GOPATH}/pkg/*

.PHONY: format
format:
	@echo "--> Running go fmt"
	@go fmt $(PACKAGES)

.PHONY: test
test: format
	@echo "--> Running go test" ;
	@go test $(UNIT_TEST_PACKAGES)


.PHONY: deps
deps:
	@echo "--> Tidying up submodules"
	@go mod tidy
	@echo "--> Verifying submodules"
	@go mod verify

.PHONY: verify-deps
verify-deps: deps
	@if !(git diff --quiet HEAD -- go.sum go.mod); then \
		echo "go module files are out of date, please commit the changes to go.mod and go.sum"; exit 1; \
	fi

.PHONY: vendor
vendor: go.mod go.sum deps
	@go mod vendor

# Bootstrap downloads tools required
# during build
.PHONY: bootstrap
bootstrap: controller-gen
	@for tool in  $(EXTERNAL_TOOLS) ; do \
		echo "+ Installing $$tool" ; \
		cd && GO111MODULE=on go get $$tool; \
	done

.PHONY: controller-gen
controller-gen:
	TMP_DIR=$(shell mktemp -d) && cd $$TMP_DIR && go mod init tmp && go get sigs.k8s.io/controller-tools/cmd/controller-gen@v0.2.8 && rm -rf $$TMP_DIR;

# SRC_PKG is the path of code files
SRC_PKG := github.com/openebs/device-localpv/pkg

# code generation for custom resources
.PHONY: kubegen
kubegen: kubegendelete deepcopy-install clientset-install lister-install informer-install
	@GEN_SRC=openebs.io/device/v1alpha1 make deepcopy clientset lister informer

# deletes generated code by codegen
.PHONY: kubegendelete
kubegendelete:
	@rm -rf pkg/generated/clientset
	@rm -rf pkg/generated/lister
	@rm -rf pkg/generated/informer

.PHONY: deepcopy-install
deepcopy-install:
	@go install ./vendor/k8s.io/code-generator/cmd/deepcopy-gen

.PHONY: deepcopy
deepcopy:
	@echo "+ Generating deepcopy funcs for $(GEN_SRC)"
	@deepcopy-gen \
		--input-dirs $(SRC_PKG)/apis/$(GEN_SRC) \
		--output-file-base zz_generated.deepcopy \
		--go-header-file ./buildscripts/custom-boilerplate.go.txt

.PHONY: clientset-install
clientset-install:
	@go install ./vendor/k8s.io/code-generator/cmd/client-gen

.PHONY: clientset
clientset:
	@echo "+ Generating clientsets for $(GEN_SRC)"
	@client-gen \
		--fake-clientset=true \
		--input $(GEN_SRC) \
		--input-base $(SRC_PKG)/apis \
		--clientset-path $(SRC_PKG)/generated/clientset \
		--go-header-file ./buildscripts/custom-boilerplate.go.txt

.PHONY: lister-install
lister-install:
	@go install ./vendor/k8s.io/code-generator/cmd/lister-gen

.PHONY: lister
lister:
	@echo "+ Generating lister for $(GEN_SRC)"
	@lister-gen \
		--input-dirs $(SRC_PKG)/apis/$(GEN_SRC) \
		--output-package $(SRC_PKG)/generated/lister \
		--go-header-file ./buildscripts/custom-boilerplate.go.txt

.PHONY: informer-install
informer-install:
	@go install ./vendor/k8s.io/code-generator/cmd/informer-gen

.PHONY: informer
informer:
	@echo "+ Generating informer for $(GEN_SRC)"
	@informer-gen \
		--input-dirs $(SRC_PKG)/apis/$(GEN_SRC) \
		--versioned-clientset-package $(SRC_PKG)/generated/clientset/internalclientset \
		--listers-package $(SRC_PKG)/generated/lister \
		--output-package $(SRC_PKG)/generated/informer \
		--go-header-file ./buildscripts/custom-boilerplate.go.txt

manifests:
	@echo "--------------------------------"
	@echo "+ Generating Device LocalPV crds"
	@echo "--------------------------------"
	$(PWD)/buildscripts/generate-manifests.sh

.PHONY: device-driver
device-driver: format
	@echo "--------------------------------"
	@echo "--> Building ${CSI_DRIVER}        "
	@echo "--------------------------------"
	@PNAME=${CSI_DRIVER} CTLNAME=${CSI_DRIVER} sh -c "'$(PWD)/buildscripts/build.sh'"

.PHONY: device-driver-image
device-driver-image: device-driver
	@echo "--------------------------------"
	@echo "+ Generating ${CSI_DRIVER} image"
	@echo "--------------------------------"
	@cp bin/${CSI_DRIVER}/${CSI_DRIVER} buildscripts/${CSI_DRIVER}/
	cd buildscripts/${CSI_DRIVER} && sudo docker build -t ${IMAGE_ORG}/${CSI_DRIVER}:${IMAGE_TAG} ${DBUILD_ARGS} . && sudo docker tag ${IMAGE_ORG}/${CSI_DRIVER}:${IMAGE_TAG} quay.io/${IMAGE_ORG}/${CSI_DRIVER}:${IMAGE_TAG}
	@rm buildscripts/${CSI_DRIVER}/${CSI_DRIVER}

# Push images
deploy-images:
	@DIMAGE="${IMAGE_ORG}/device-driver" ./buildscripts/push

.PHONY: golint
golint:
	@echo "--> Running golint"
	@golint -set_exit_status $(PACKAGES)
	@echo "Completed golint no recommendations !!"
	@echo "--------------------------------"
	@echo ""

.PHONY: license-check
license-check:
	@echo "--> Checking license header..."
	@licRes=$$(for file in $$(find . -type f -regex '.*\.sh\|.*\.go\|.*Docker.*\|.*\Makefile*' ! -path './vendor/*' ) ; do \
               awk 'NR<=5' $$file | grep -Eq "(Copyright|generated|GENERATED)" || echo $$file; \
       done); \
       if [ -n "$${licRes}" ]; then \
               echo "license header checking failed:"; echo "$${licRes}"; \
               exit 1; \
       fi
	@echo "--> Done checking license."
	@echo

include Makefile.buildx.mk
