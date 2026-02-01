# =============================================================================
# Adaptive-Breakout-EA Makefile
# =============================================================================
# This Makefile provides a unified interface for:
# - Installing Python dependencies
# - Linting and testing
# - Validating configs (lightweight)
# - Building a ZIP artifact for manual MT deployment
#
# Targets (most common):
#   make install     - install Python dependencies
#   make lint        - run ruff on the python/ tree
#   make test        - run pytest
#   make validate    - lightweight config validation (best-effort)
#   make package     - build dist/Adaptive-Breakout-EA-<sha>.zip
#   make ci          - run the full CI pipeline (install + checks + package)
#
# Notes:
# - This Makefile intentionally does NOT try to compile MQL4/5 code; it only
#   collects repo files into a ZIP so you can scaffold MT manually.
# - Adjust the ZIP content list in the "package" target if you want more/less
#   files in the artifact.
# =============================================================================

PYTHON      := python
PIP         := pip

PROJECT_NAME := Adaptive-Breakout-EA
DIST_DIR     := dist
GIT_SHA      := $(shell git rev-parse --short HEAD 2>/dev/null || echo local)
ARTIFACT_NAME := $(PROJECT_NAME)-$(GIT_SHA).zip

# Folders that are packaged into the artifact
EA_DIR        := eas
CONFIG_DIR    := configs
DASHBOARD_DIR := dashboards
DOCS_DIR      := docs
FILES_DIR     := Files
PYTHON_DIR    := python

# -----------------------------------------------------------------------------
# Default target
# -----------------------------------------------------------------------------

.PHONY: all
all: lint test

# -----------------------------------------------------------------------------
# Environment / dependencies
# -----------------------------------------------------------------------------

.PHONY: install
install:
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

# -----------------------------------------------------------------------------
# Linting / formatting
# -----------------------------------------------------------------------------

.PHONY: lint
lint:
	# Python linting with ruff (configured by ruff.toml)
	ruff check $(PYTHON_DIR)

.PHONY: format
format:
	# Optional auto-fix using ruff
	ruff check $(PYTHON_DIR) --fix

# -----------------------------------------------------------------------------
# Testing
# -----------------------------------------------------------------------------

.PHONY: test
test:
	pytest

# -----------------------------------------------------------------------------
# Lightweight config validation
# -----------------------------------------------------------------------------
# If you later add a real config validation script, wire it in here.
# For now this target is a placeholder that simply checks that configs/
# exists and is not empty (best-effort, non-fatal).

.PHONY: validate
validate:
	@if [ -d "$(CONFIG_DIR)" ]; then \
		if find "$(CONFIG_DIR)" -type f -name '*.yml' -o -name '*.yaml' | grep -q .; then \
			echo "Found config files under $(CONFIG_DIR)."; \
		else \
			echo "No YAML config files found under $(CONFIG_DIR); skipping deep validation."; \
		fi \
	else \
		echo "$(CONFIG_DIR) directory not found; skipping config validation."; \
	fi

# -----------------------------------------------------------------------------
# Packaging for MT (ZIP artifact)
# -----------------------------------------------------------------------------

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

.PHONY: package
package: $(DIST_DIR)
	# Build a ZIP for manual MT scaffolding.
	# This collects the EA sources, configs, dashboards, docs, and support files.
	# If some paths don't exist, we continue and create a partial ZIP.
	@echo "Building artifact $(DIST_DIR)/$(ARTIFACT_NAME)"
	cd $(DIST_DIR) && \
	zip -r "$(ARTIFACT_NAME)" \
		"../$(EA_DIR)" \
		"../$(CONFIG_DIR)" \
		"../$(DASHBOARD_DIR)" \
		"../$(DOCS_DIR)" \
		"../$(FILES_DIR)" \
		"../$(PYTHON_DIR)" \
		"../README.md" \
		"../ROADMAP.md" \
		2>/dev/null || echo "Some paths may be missing; ZIP created with available files."

# -----------------------------------------------------------------------------
# CI convenience target
# -----------------------------------------------------------------------------

.PHONY: ci
ci: install lint test validate package
