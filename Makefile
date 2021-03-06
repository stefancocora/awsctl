# make configs taken from kubernetes
DBG_MAKEFILE ?=
ifeq ($(DBG_MAKEFILE),1)
    $(warning ***** starting Makefile for goal(s) "$(MAKECMDGOALS)")
    $(warning ***** $(shell date))
    $(warning ***** setting debug flags for containers)
		DEBUG = true
else
    # If we're not debugging the Makefile, don't echo recipes.
    MAKEFLAGS += -s
		DEBUG = false
endif
# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash
# We don't need make's built-in rules.
MAKEFLAGS += --no-builtin-rules

# constants
ELF_NAME = awsctl
ELF_APPENVIRONMENT = dev
build_production: ELF_APPENVIRONMENT = production
ELF_VERSION ?= '0.0.1' # build script adds the v in front of the semver.org version
BUILD_ACTION = build
unit: BUILD_ACTION = unit

# OS = $(shell grep "^ID=" /etc/os-release | awk -F"=" '{print $2}')
OS = $(shell grep "^ID=" /etc/os-release | cut -d"=" -f2 )
BUILD_TIMEOUT = 120 # seconds

CONTAINER_IMAGENAME = 'stefancocora/$(ELF_NAME)'
CONTAINER_VERSION = v$(ELF_VERSION)
CONTAINER_NAME := '$(ELF_NAME)'
CONTAINER_NOCACHE := 'nocache'
container_iterateimage : CONTAINER_NOCACHE = 'withcache'
CONTAINER_BUILD_ACTION := 'build'
container_exportToRkt: CONTAINER_BUILD_ACTION = 'rkt'
container_rktinteractive: CONTAINER_BUILD_ACTION = 'rktinteractive'

GRAPHICS_SRC_DIR = $(CURDIR)/graphicsrc
GRAPHICS_TARGET_DIR = $(CURDIR)/graphictarget
# DOT_FILES = $(wildcard $(GRAPHICS_SRC_DIR)/dot/*.dot)
# IMAGES = $(patsubst %.dot, %, $(DOT_FILES))
PLANTUML_DIR = $(GRAPHICS_SRC_DIR)/plantuml
PLANTUML_IMAGE = "docker://think/plantuml:latest"
# CI vars
CI_TARGET_LOCAL := minikube_conc
VG_PIPELINENAME_MASTER := $(ELF_NAME)
VG_PIPELINENAME_BRANCH := $(ELF_NAME)_branch
VG_PIPELINENAME_GH_MASTER := $(ELF_NAME)_gh
VG_PIPELINENAME_PRS := $(ELF_NAME)_prs
CI_PIPELINES_PATH := ci
CI_MASTER_PIPELINE := master.yml
CI_BRANCH_PIPELINE := branch.yml
CI_MASTER_GH_PIPELINE := master_gh.yml
CI_PRS_PIPELINE := prs.yml


# Metadata for driving the build lives here.
META_DIR := .make

.PHONY: build test help gotags graphicswatch tmux

# define a catchall target
# default: build
default: help

graphics: dot uml

help:
	@echo "---> Help menu:"
	@echo "supported make targets:"
	@echo ""
	@echo "Build the binary, for the dev or production APPVERSION:"
	@echo "  make build"
	@echo "  make build_production"
	@echo "  make unit"
	@echo ""
	@echo "Container build targets:"
	@echo "  make build_cont_interactive		# builds binary and creates a container image with this newly built binary"
	@echo "  make container_docker_to_rkt		# creates the docker image and exports the image to the rkt store"
	@echo "  make container_exportToRkt		# exports the docker image to the rkt store"
	@echo "  make container_image			# builds a container image without caching"
	@echo "  make container_iterateimage		# builds a container image without caching"
	@echo "  make container_interactive		# drops into the shell of built image"
	@echo "  make container_listi			# lists the already created image"
	@echo "  make container_rktinteractive		# runs an interactive rkt container"
	@echo "  make container_test			# test container image with goss"
	@echo ""
	@echo "CI targets:"
	@echo "  make set_pipeline_branch"
	@echo "  make set_pipeline_master"
	@echo "  make set_pipeline_prs"
	@echo "  make set_pipeline_master_gh"
	@echo ""
	@echo "Add license headers:"
	@echo "  make add_license"
	@echo ""
	@echo "Regenerating the golang tags:"
	@echo "  make gotags"
	@echo ""
	@echo "Regen project dot and uml graphics"
	@echo "  make graphics"
	@echo ""
	@echo "Watch for changes to graphics files and show the files"
	@echo "  make graphicswatch"
	@echo ""
	@echo "Will tell compiler to show us memory allocations, please grep for the source file you're interested in or get all output ..."
	@echo "  make memalloc"
	@echo ""
	@echo "Start tmux session"
	@echo "  make tmux"
	@echo ""
	@echo "Watch for changes to source code and recompile"
	@echo "  make watch"

.PHONY: build_production
build_production:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "--> Building ELF ..."
ifeq ($(OS),alpine)
	$(info detected OS: $(OS))
	timeout -t $(BUILD_TIMEOUT) util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG) $(BUILD_ACTION)
else
	$(info detected OS: $(OS))
	timeout --preserve-status $(BUILD_TIMEOUT) util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG) $(BUILD_ACTION)
endif

.PHONY: build
build:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "--> Building ELF ..."
  # docker build -t ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION} .
ifeq ($(OS),alpine)
	$(info detected OS: $(OS))
	timeout -t $(BUILD_TIMEOUT) util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG) $(BUILD_ACTION)
else
	$(info detected OS: $(OS))
	timeout --preserve-status $(BUILD_TIMEOUT) util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG) $(BUILD_ACTION)
endif

.PHONY: unit
unit:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "--> Unit testing ..."
ifeq ($(OS),alpine)
	$(info detected OS: $(OS))
	timeout -t $(BUILD_TIMEOUT) util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG) $(BUILD_ACTION)
else
	$(info detected OS: $(OS))
	timeout --preserve-status $(BUILD_TIMEOUT) util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG) $(BUILD_ACTION)
endif

.PHONY: build_cont_interactive
build_cont_interactive:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	$(MAKE) build
	$(MAKE) container_iterateimage

.PHONY: container_image
container_image:
	@echo "--> Building container image without caches..."
ifeq ($(DEBUG),true)
	$(info version: $(CONTAINER_BUILD_ACTION))
	$(info version: $(CONTAINER_VERSION))
	$(info nocache: $(CONTAINER_NOCACHE))
	$(info imagename: $(CONTAINER_IMAGENAME))
	$(info debug: $(DEBUG))
endif
	timeout --preserve-status 120s util/buildcontainer.sh $(CONTAINER_BUILD_ACTION) $(CONTAINER_VERSION) $(CONTAINER_NOCACHE) $(CONTAINER_IMAGENAME) $(DEBUG)

.PHONY: container_iterateimage
container_iterateimage:
	@echo "--> Building container image ..."
ifeq ($(DEBUG),true)
	$(info containerbuildaction: $(CONTAINER_BUILD_ACTION))
	$(info version: $(CONTAINER_VERSION))
	$(info nocache: $(CONTAINER_NOCACHE))
	$(info imagename: $(CONTAINER_IMAGENAME))
	$(info debug: $(DEBUG))
endif
	timeout --preserve-status 120s util/buildcontainer.sh $(CONTAINER_BUILD_ACTION) $(CONTAINER_VERSION) $(CONTAINER_NOCACHE) $(CONTAINER_IMAGENAME) $(DEBUG)

.PHONY: container_exportToRkt
container_exportToRkt:
	@echo "--> Exporting container to the rkt store..."
ifeq ($(DEBUG),true)
	$(info containerbuildaction: $(CONTAINER_BUILD_ACTION))
	$(info version: $(CONTAINER_VERSION))
	$(info nocache: $(CONTAINER_NOCACHE))
	$(info imagename: $(CONTAINER_IMAGENAME))
	$(info debug: $(DEBUG))
endif
	timeout --preserve-status 120s util/buildcontainer.sh $(CONTAINER_BUILD_ACTION) $(CONTAINER_VERSION) $(CONTAINER_NOCACHE) $(CONTAINER_IMAGENAME) $(DEBUG)

# http://stackoverflow.com/questions/5377297/how-to-manually-call-another-target-from-a-make-target#27132934
# http://stackoverflow.com/questions/8756522/how-to-use-a-for-loop-in-make-recipe
.PHONY: container_docker_to_rkt
container_docker_to_rkt:
	@echo "--> Creating docker container and exporting container to the rkt store..."
	@echo "-----> Cleaning old docker containers"
	for im in `docker images |grep $(CONTAINER_NAME)| awk '{print $$3}'`; do \
		docker rmi $$im; \
	done
	@echo "-----> Cleaning old rkt containers"
	for im in `rkt image list |grep $(CONTAINER_NAME)| awk '{print $$1}'`; do \
		rkt image rm $$im; \
	done
	$(MAKE) build
	$(MAKE) container_iterateimage
	$(MAKE) container_test
	$(MAKE) container_exportToRkt

.PHONY: container_rktinteractive
container_rktinteractive:
	@echo "--> Running rkt container interactively ..."
ifeq ($(DEBUG),true)
	$(info containerbuildaction: $(CONTAINER_BUILD_ACTION))
	$(info version: $(CONTAINER_VERSION))
	$(info nocache: $(CONTAINER_NOCACHE))
	$(info imagename: $(CONTAINER_IMAGENAME))
	$(info debug: $(DEBUG))
endif
	util/buildcontainer.sh $(CONTAINER_BUILD_ACTION) $(CONTAINER_VERSION) $(CONTAINER_NOCACHE) $(CONTAINER_IMAGENAME) $(DEBUG)

.PHONY: container_interactive
container_interactive:
	@echo "---> Running interactively ..."
	@echo "---> You can test bats tests from /awsctl/test/bats/ ..."
ifeq ($(DEBUG),true)
	$(info container_name: $(CONTAINER_NAME))
	$(info imagename: $(CONTAINER_IMAGENAME))
	$(info version: $(CONTAINER_VERSION))
	$(info debug: $(DEBUG))
endif
	docker run \
	  -v $(CURDIR)/test:/$(ELF_NAME)/test \
	  -v $(shell echo ${HOME})/.aws/credentials:/home/$(ELF_NAME)/.aws/credentials:ro \
	  -v $(CURDIR)/util/terraform-modules:/home/$(ELF_NAME)/terraform-modules \
		--rm \
		-ti \
		--name $(CONTAINER_NAME) $(CONTAINER_IMAGENAME):$(CONTAINER_VERSION)

.PHONY: container_listi
container_listi:
	@echo "---> Listing the already created image ..."
ifeq ($(DEBUG),true)
	$(info version: $(CONTAINER_VERSION))
	$(info debug: $(DEBUG))
endif
	docker images | grep $(CONTAINER_IMAGENAME)

.PHONY: container_removec
container_removec:
	@echo "---> Stopping and removing the container ..."
ifeq ($(DEBUG),true)
	$(info version: $(CONTAINER_NAME))
	$(info debug: $(DEBUG))
endif
	docker kill $(CONTAINER_NAME)

.PHONY: container_removei
container_removei:
ifeq ($(DEBUG),true)
	$(info imagename: $(CONTAINER_IMAGENAME))
	$(info version: $(CONTAINER_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "---> Removing the image ..."
	docker rmi $(CONTAINER_IMAGENAME):$(CONTAINER_VERSION)

# tag:
#         @echo "---> tagging the git repo"
#         @echo "not implemented yet"
#
.PHONY: container_test
container_test:
	@echo "--> Testing image ..."
ifeq ($(DEBUG),true)
	$(info version: $(CONTAINER_VERSION))
	$(info version: $(CONTAINER_IMAGENAME))
	$(info debug: $(DEBUG))
endif
	util/goss.sh $(CONTAINER_VERSION) $(CONTAINER_IMAGENAME)

###########

dot:
	@echo "nothing yet"

# %: %.dot target
# 	dot -Tpng -Gimagepath="$(SRC_DIR)/img" "$<" -o"$(TARGET_DIR)/$(*F).png"

gotags:
	@echo "---> Regen-ing the golang tags ..."
	util/gotags.sh

graphicswatch:
	@echo "---> Reloading graphics files ..."
	util/entrplantuml.sh view

memalloc:
	@echo "---> Will tell compiler to show us memory allocations, please grep for the source file you're interested in or get all output ..."
	util/bench_and_prof.sh memalloc $(DEBUG)

tmux:
				tmuxp load .

uml:
	@echo "---> generating png from plantuml files in a rkt container"
	# $(info $(PLANTUML_IMAGE))
	# $(info $(PLANTUML_DIR))
	# $(info $(GRAPHICS_TARGET_DIR))
	# $(info $(DEBUG))
	util/entrplantuml.sh create $(PLANTUML_IMAGE) $(PLANTUML_DIR) $(GRAPHICS_TARGET_DIR) $(DEBUG)

# .PHONY: build
# build:
# ifeq ($(DEBUG),true)
# 	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
# 	$(info elf version: $(ELF_VERSION))
# 	$(info debug: $(DEBUG))
# endif
# 	@echo "--> Building ELF ..."
#   # docker build -t ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION} .
# 	timeout --preserve-status 120s util/build.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG)
#
.PHONY: watch
watch:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "---> Building ELF and watching directory for changes ..."
	util/entrbuild.sh $(ELF_APPENVIRONMENT) $(ELF_VERSION) $(DEBUG)

.PHONY: set_pipeline_branch
set_pipeline_branch:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "---> Applying CI pipeline ..."
	fly -t $(CI_TARGET_LOCAL) set-pipeline -c $(CI_PIPELINES_PATH)/$(CI_BRANCH_PIPELINE) -p $(VG_PIPELINENAME_BRANCH)
	fly -t $(CI_TARGET_LOCAL) expose-pipeline --pipeline $(VG_PIPELINENAME_BRANCH)

.PHONY: set_pipeline_master
set_pipeline_master:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "---> Applying CI pipeline ..."
	fly -t $(CI_TARGET_LOCAL) set-pipeline -c $(CI_PIPELINES_PATH)/$(CI_MASTER_PIPELINE) -p $(VG_PIPELINENAME_MASTER)
	fly -t $(CI_TARGET_LOCAL) expose-pipeline --pipeline $(VG_PIPELINENAME_MASTER)

.PHONY: set_pipeline_prs
set_pipeline_prs:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "---> Applying CI pipeline ..."
	fly -t $(CI_TARGET_LOCAL) set-pipeline -c $(CI_PIPELINES_PATH)/$(CI_PRS_PIPELINE) -p $(VG_PIPELINENAME_PRS)
	fly -t $(CI_TARGET_LOCAL) expose-pipeline --pipeline $(VG_PIPELINENAME_PRS)

.PHONY: set_pipeline_master_gh
set_pipeline_master_gh:
ifeq ($(DEBUG),true)
	$(info elf appenvironment: $(ELF_APPENVIRONMENT))
	$(info elf version: $(ELF_VERSION))
	$(info debug: $(DEBUG))
endif
	@echo "---> Applying CI pipeline ..."
	fly -t $(CI_TARGET_LOCAL) set-pipeline -c $(CI_PIPELINES_PATH)/$(CI_MASTER_GH_PIPELINE) -p $(VG_PIPELINENAME_GH_MASTER)
	fly -t $(CI_TARGET_LOCAL) expose-pipeline --pipeline $(VG_PIPELINENAME_GH_MASTER)

.PHONY: add_license
add_license:
	util/license/add-license-header.sh
