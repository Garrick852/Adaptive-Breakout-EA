# =============================================================================
# Adaptive-Breakout-EA Makefile
# =============================================================================
# This Makefile provides a unified interface for:
# - Installing Python dependencies
# - Linting and testing
# - Validating configs (lightweight)
# - Building an MT5-style ZIP artifact for manual deployment
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
# - This Makefile does not compile MQL; it only packages files into an
#   MT5-style folder layout (MQL5/Experts, MQL5/Include, etc.).
# =============================================================================

PYTHON      := python
PIP         := pip

PROJECT_NAME  := Adaptive-Breakout-EA
DIST_DIR      := dist
GIT_SHA       := $(shell git rev-parse --short HEAD 2>/dev/null || echo local)
ARTIFACT_NAME := $(PROJECT_NAME)-$(GIT_SHA).zip

# -----------------------------------------------------------------------------
# SOURCE LAYOUT (in this repo)
# -----------------------------------------------------------------------------

# Root folders in the repo
EA_SRC_ROOT     := eas
CONFIG_DIR      := configs
DASHBOARD_DIR   := dashboards
DOCS_DIR        := docs
FILES_DIR       := Files
PYTHON_DIR      := python

# If you have a specific EA folder, set it here; otherwise we just copy all of eas/
# Example (uncomment and adjust if you want it tighter):
# EA_MAIN_DIR   := $(EA_SRC_ROOT)/AdaptiveBreakoutAI
# For now, use the whole eas tree:
EA_MAIN_DIR     := $(EA_SRC_ROOT)

# If you have shared includes (.mqh) in a dedicated directory, point this there.
# Otherwise this can just mirror EA_MAIN_DIR or a subfolder.
EA_INCLUDE_DIR  := $(EA_MAIN_DIR)

# -----------------------------------------------------------------------------
# MT5 PACKAGING LAYOUT (inside the ZIP)
# -----------------------------------------------------------------------------
# The ZIP will contain this structure:
#
#   MQL5/
#     Experts/
#       AdaptiveBreakoutEA/   <- EA .mq5/.ex5 from EA_MAIN_DIR
#     Include/
#       AdaptiveBreakoutEA/   <- .mqh and shared includes from EA_INCLUDE_DIR
#   configs/                  <- YAML configs as reference
#   dashboards/
#   docs/
#   Files/
#   python/
#   README.md
#   ROADMAP.md
# -----------------------------------------------------------------------------

MQL5_ROOT           := MQL5
MQL5_EXPERTS_DIR    := $(MQL5_ROOT)/Experts/AdaptiveBreakoutEA
MQL5_INCLUDE_DIR    := $(MQL5_ROOT)/Include/AdaptiveBreakoutEA

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

.PHONY: validate
validate:
	@if [ -d "$(CONFIG_DIR)" ]; then \
		if find "$(CONFIG_DIR)" -type f \( -name '*.yml' -o -name '*.yaml' \) | grep -q .; then \
			echo "Found config files under $(CONFIG_DIR)."; \
		else \
			echo "No YAML config files found under $(CONFIG_DIR); skipping deep validation."; \
		fi; \
	else \
		echo "$(CONFIG_DIR) directory not found; skipping config validation."; \
	fi

# -----------------------------------------------------------------------------
# Packaging helpers
# -----------------------------------------------------------------------------

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

# -----------------------------------------------------------------------------
# Packaging for MT5 (ZIP artifact, MT-style layout)
# -----------------------------------------------------------------------------

.PHONY: package
package: $(DIST_DIR)
	@echo "Building MT5 artifact $(DIST_DIR)/$(ARTIFACT_NAME)"
	# Create a temporary staging directory inside dist
	rm -rf $(DIST_DIR)/staging
	mkdir -p $(DIST_DIR)/staging/$(MQL5_EXPERTS_DIR)
	mkdir -p $(DIST_DIR)/staging/$(MQL5_INCLUDE_DIR)

	# Copy EA sources/binaries into MQL5/Experts/AdaptiveBreakoutEA
	if [ -d "$(EA_MAIN_DIR)" ]; then \
		cp -r "$(EA_MAIN_DIR)/"*.mq* "$(DIST_DIR)/staging/$(MQL5_EXPERTS_DIR)/" 2>/dev/null || true; \
		cp -r "$(EA_MAIN_DIR)" "$(DIST_DIR)/staging/$(MQL5_EXPERTS_DIR)/src" 2>/dev/null || true; \
	else \
		echo "WARNING: EA source directory $(EA_MAIN_DIR) not found"; \
	fi

	# Copy includes (.mqh) into MQL5/Include/AdaptiveBreakoutEA
	if [ -d "$(EA_INCLUDE_DIR)" ]; then \
		find "$(EA_INCLUDE_DIR)" -type f -name '*.mqh' -exec cp {} "$(DIST_DIR)/staging/$(MQL5_INCLUDE_DIR)/" \; 2>/dev/null || true; \
	fi

	# Copy supporting project files next to MQL5 folder (docs, configs, etc.)
	if [ -d "$(CONFIG_DIR)" ]; then \
		cp -r "$(CONFIG_DIR)" "$(DIST_DIR)/staging/"; \
	fi
	if [ -d "$(DASHBOARD_DIR)" ]; then \
		cp -r "$(DASHBOARD_DIR)" "$(DIST_DIR)/staging/"; \
	fi
	if [ -d "$(DOCS_DIR)" ]; then \
		cp -r "$(DOCS_DIR)" "$(DIST_DIR)/staging/"; \
	fi
	if [ -d "$(FILES_DIR)" ]; then \
		cp -r "$(FILES_DIR)" "$(DIST_DIR)/staging/"; \
	fi
	if [ -d "$(PYTHON_DIR)" ]; then \
		cp -r "$(PYTHON_DIR)" "$(DIST_DIR)/staging/"; \
	fi
	if [ -f "README.md" ]; then \
		cp "README.md" "$(DIST_DIR)/staging/"; \
	fi
	if [ -f "ROADMAP.md" ]; then \
		cp "ROADMAP.md" "$(DIST_DIR)/staging/"; \
	fi

	# Build the ZIP from staging/
	cd $(DIST_DIR)/staging && \
	zip -r "../$(ARTIFACT_NAME)" . && \
	cd ../.. && \
	rm -rf $(DIST_DIR)/staging

# -----------------------------------------------------------------------------
# CI convenience target
# -----------------------------------------------------------------------------

.PHONY: ci
ci: install lint test validate package
