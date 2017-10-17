# make configs taken from kubernetes
DBG_MAKEFILE ?=
ifeq ($(DBG_MAKEFILE),1)
    $(warning ***** starting Makefile for goal(s) "$(MAKECMDGOALS)")
    $(warning ***** $(shell date))
else
    # If we're not debugging the Makefile, don't echo recipes.
    MAKEFLAGS += -s
endif
# It's necessary to set this because some environments don't link sh -> bash.
SHELL := /bin/bash
# We don't need make's built-in rules.
MAKEFLAGS += --no-builtin-rules

# constants
NAME = awsgocli
# AUTHOR ?= ukhomeofficedigital
# REGISTRY ?= quay.io
# VERSION ?= latest

# Metadata for driving the build lives here.
META_DIR := .make

.PHONY: build test help gotags

# define a catchall target
# default: build
default: help

help:
	@echo "---> Help menu:"
	@echo "supported make targets:"
	@echo ""
	@echo "Build the binary:"
	@echo "  make build"
	@echo ""
	@echo "Regenerating the golang tags:"
	@echo "  make gotags"
	@echo ""
	@echo "Run a filestystem inotify watcher:"
	@echo "  make watch"


build:
				@echo "--> Building ..."
        # docker build -t ${REGISTRY}/${AUTHOR}/${NAME}:${VERSION} .
				util/build.sh

gotags:
				@echo "---> Regen-ing the golang tags ..."
				util/gotags.sh

watch:
				@echo "---> Building and watching directory for chages ..."
				util/entrbuild.sh
