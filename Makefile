# Dockershelf Go packaging pipeline (Debian-native, precompiled repackage)
#
# Run from go-pipeline/ inside the dockershelf-pipeline workspace.
# Sibling go* repos live in the parent directory (..).
#
# Quick start:
#   cp config.env.example config.env
#   make bootstrap
#   make build-builder-images
#   make materialize GO=1.25 DIST=trixie
#   make build GO=1.25
#   make publish DIST=trixie

SHELL := bash -euo pipefail
PIPELINE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
WORKSPACE := $(abspath $(PIPELINE)/..)
DIST_DIR := $(PIPELINE)/dist

ifneq (,$(wildcard $(PIPELINE)/config.env))
include $(PIPELINE)/config.env
endif
export DOCKERSHELF_BUILDER_IMAGE ?= dockershelf-builder
export DOCKERSHELF_TOOLS_IMAGE ?= dockershelf-builder/tools
export DOCKERSHELF_ARCH ?= amd64
ifdef DEBFULLNAME
export DEBFULLNAME
endif
ifdef DEBEMAIL
export DEBEMAIL
endif
export DOCKERSHELF_SUITES ?= trixie unstable
export DOCKERSHELF_REFERENCE_GO ?= 1.25
export DOCKERSHELF_DEPLOY_HOST ?= apt.dockershelf.example
export DOCKERSHELF_DEPLOY_USER ?= deploy
export DOCKERSHELF_DEPLOY_DIR ?= /var/www/debian
export DOCKERSHELF_DEPLOY_INCOMING ?= /var/www/debian/incoming
export DOCKERSHELF_APT_URL ?= https://apt.dockershelf.example/debian
export DOCKERSHELF_GITHUB_ORG ?= Dockershelf

GO_VERSIONS := 1.20 1.21 1.22 1.23 1.24 1.25

.PHONY: all bootstrap clone-go-repos build-tools-image generate-dockerfiles build-builder-images \
	materialize build publish smoke list-dists help

all: help

help:
	@echo "Targets:"
	@echo "  bootstrap                 Clone or seed go* repos into workspace parent"
	@echo "  build-tools-image         Build dockershelf-builder/tools (gbp, dch, …)"
	@echo "  generate-dockerfiles      Generate Dockerfile.{suite} from debian/control"
	@echo "  build-builder-images      Build dockershelf-builder/* (Debian base)"
	@echo "  materialize GO=1.25 DIST=trixie"
	@echo "  build GO=1.25             Build binary .deb packages (unsigned)"
	@echo "  publish DIST=trixie       Rsync dist/*.deb to DO droplet + reprepro import"
	@echo "  smoke GO=1.25 DIST=trixie  Install debs in a container and run smoke tests"
	@echo "  list-dists                Show Debian suites per go repo"
	@echo ""
	@echo "Config: copy config.env.example to config.env"

bootstrap: clone-go-repos
	@echo "Bootstrap complete."

clone-go-repos:
	@for v in $(GO_VERSIONS); do \
		target="$(WORKSPACE)/go$$v"; \
		if [ -d "$$target/.git" ]; then \
			echo "go$$v already present"; \
		elif git clone --depth 1 "https://github.com/$(DOCKERSHELF_GITHUB_ORG)/go$$v.git" "$$target" 2>/dev/null; then \
			echo "Cloned go$$v from GitHub"; \
		else \
			echo "Seeding go$$v from template..."; \
			"$(PIPELINE)/scripts/seed-go-repo.sh" "$$v" "$$target" || \
				echo "WARN: could not seed go$$v (skipping)"; \
		fi; \
	done

build-tools-image:
	@echo "Building $(DOCKERSHELF_TOOLS_IMAGE)"
	@docker build -t "$(DOCKERSHELF_TOOLS_IMAGE)" \
		-f "$(PIPELINE)/dockerfiles/Dockerfile.tools" "$(PIPELINE)/dockerfiles"

generate-dockerfiles:
	@mkdir -p "$(PIPELINE)/dockerfiles"
	@REF="$(WORKSPACE)/go$(DOCKERSHELF_REFERENCE_GO)/debiandirs"; \
	if [ ! -d "$$REF" ]; then \
		echo "ERROR: missing $$REF — seed or clone go$(DOCKERSHELF_REFERENCE_GO) first"; \
		exit 1; \
	fi; \
	for suite in $(DOCKERSHELF_SUITES); do \
		control="$$REF/$$suite/control"; \
		if [ ! -f "$$control" ]; then \
			echo "ERROR: missing $$control"; \
			exit 1; \
		fi; \
		echo "Generating Dockerfile.$$suite"; \
		"$(PIPELINE)/make-new-image" --codename "$$suite" "$$control" \
			> "$(PIPELINE)/dockerfiles/Dockerfile.$$suite"; \
	done

build-builder-images: generate-dockerfiles build-tools-image
	@for suite in $(DOCKERSHELF_SUITES); do \
		df="$(PIPELINE)/dockerfiles/Dockerfile.$$suite"; \
		if [ ! -f "$$df" ]; then \
			echo "ERROR: missing $$df (run make generate-dockerfiles)"; \
			exit 1; \
		fi; \
		echo "Building $(DOCKERSHELF_BUILDER_IMAGE)/$$suite"; \
		docker build -t "$(DOCKERSHELF_BUILDER_IMAGE)/$$suite" -f "$$df" "$(PIPELINE)/dockerfiles"; \
	done

list-dists:
	@for v in $(GO_VERSIONS); do \
		if [ -d "$(WORKSPACE)/go$$v/changelogs/mainline" ]; then \
			suites=""; \
			for s in $(DOCKERSHELF_SUITES); do \
				if [ -f "$(WORKSPACE)/go$$v/changelogs/mainline/$$s" ]; then \
					suites="$$suites $$s"; \
				fi; \
			done; \
			echo "go$$v:$$suites"; \
		fi; \
	done

materialize: bootstrap build-tools-image
	@test -n "$(GO)" || (echo "GO required, e.g. make materialize GO=1.25 DIST=trixie" && exit 1)
	@test -n "$(DIST)" || (echo "DIST required, e.g. DIST=trixie" && exit 1)
	@case " $(DOCKERSHELF_SUITES) " in \
		*" $(DIST) "*) ;; \
		*) echo "DIST must be one of: $(DOCKERSHELF_SUITES)"; exit 1;; \
	esac
	@cd "$(WORKSPACE)/go$(GO)" && ../go-pipeline/meta-gbp materialize "$(DIST)"

build: bootstrap build-tools-image
	@test -n "$(GO)" || (echo "GO required" && exit 1)
	@mkdir -p "$(DIST_DIR)"
	@cd "$(WORKSPACE)/go$(GO)" && ../go-pipeline/meta-gbp build
	@echo "Packages written to $(DIST_DIR)/"

smoke:
	@test -n "$(GO)" || (echo "GO required, e.g. make smoke GO=1.25 DIST=unstable" && exit 1)
	@test -n "$(DIST)" || (echo "DIST required, e.g. DIST=unstable" && exit 1)
	@bash "$(PIPELINE)/scripts/debian-smoke-test.sh" \
		--dist "$(DIST)" --go "$(GO)" --dist-dir "$(DIST_DIR)"

publish:
	@test -n "$(DIST)" || (echo "DIST required, e.g. make publish DIST=trixie" && exit 1)
	@shopt -s nullglob; debs=("$(DIST_DIR)"/*.deb); \
	if [ "$${#debs[@]}" -eq 0 ]; then \
		echo "No .deb files in $(DIST_DIR)/ — run make build first"; \
		exit 1; \
	fi; \
	echo "Publishing $${#debs[@]} package(s) to $(DOCKERSHELF_DEPLOY_USER)@$(DOCKERSHELF_DEPLOY_HOST):$(DOCKERSHELF_DEPLOY_INCOMING)/"; \
	rsync -av --progress "$${debs[@]}" \
		"$(DOCKERSHELF_DEPLOY_USER)@$(DOCKERSHELF_DEPLOY_HOST):$(DOCKERSHELF_DEPLOY_INCOMING)/"; \
	ssh "$(DOCKERSHELF_DEPLOY_USER)@$(DOCKERSHELF_DEPLOY_HOST)" \
		"REPO_ROOT=$(DOCKERSHELF_DEPLOY_DIR) INCOMING=$(DOCKERSHELF_DEPLOY_INCOMING) \
		/usr/local/bin/dockershelf-import-incoming $(DIST) || \
		bash -s $(DIST)" < "$(PIPELINE)/debian-repo-setup/import-incoming.sh"; \
	echo "Published to $(DOCKERSHELF_APT_URL) ($(DIST))"
