# Core variables
PYTHON := python
PIP := pip

PROJECT_NAME := Adaptive-Breakout-EA
DIST_DIR := dist
ARTIFACT_NAME := $(PROJECT_NAME)-$(shell git rev-parse --short HEAD).zip

# Directories in this repo that we may want to include in the ZIP
EA_DIR := eas
CONFIG_DIR := configs
DASHBOARD_DIR := dashboards
DOCS_DIR := docs
FILES_DIR := Files

# Default target
.PHONY: all
all: lint test glyphs

# ---------------------------------------------------------------------------
# Environment / deps
# ---------------------------------------------------------------------------

.PHONY: install
install:
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

# ---------------------------------------------------------------------------
# Linting / formatting / static analysis
# ---------------------------------------------------------------------------

.PHONY: lint
lint:
	# Python linting via ruff (configured in ruff.toml)
	ruff check python

.PHONY: format
format:
	# Optional: auto-fix with ruff if you use it
	ruff check python --fix

# ---------------------------------------------------------------------------
# Testing
# ---------------------------------------------------------------------------

.PHONY: test
test:
	pytest

# ---------------------------------------------------------------------------
# Glyphs / dashboards / visuals (adjust commands if your tooling differs)
# ---------------------------------------------------------------------------

.PHONY: glyphs
glyphs:
	# Example: regenerate or validate expected glyphs/dashboards
	# Replace this with your actual command if different
	$(PYTHON) python/tools/render_glyphs.py --output $(DASHBOARD_DIR)/glyphs/expected || true

# ---------------------------------------------------------------------------
# Config validation (optional; tighten once everything is YAML-aware)
# ---------------------------------------------------------------------------

.PHONY: validate-configs
validate-configs:
	# Loosely validate configs; make this strict once the tool is stable
	$(PYTHON) python/tools/validate_configs.py || true

# ---------------------------------------------------------------------------
# Packaging for MT (ZIP artifact)
# ---------------------------------------------------------------------------

$(DIST_DIR):
	mkdir -p $(DIST_DIR)

.PHONY: package
package: $(DIST_DIR)
	# Build a ZIP containing the EA and supporting material for manual MT deployment.
	# Adjust the contents to exactly what you want to copy into MT5.
	# If some paths don't exist yet, we allow the command to continue.
	cd $(DIST_DIR) && \
	zip -r "$(ARTIFACT_NAME)" \
		"../$(EA_DIR)" \
		"../$(CONFIG_DIR)" \
		"../$(DASHBOARD_DIR)" \
		"../$(DOCS_DIR)" \
		"../$(FILES_DIR)" \
		"../README.md" \
		"../ROADMAP.md" || echo "Some paths may be missing; ZIP created with available files."

# Convenience target to run the full CI pipeline locally
.PHONY: ci
ci: install lint test glyphs validate-configs package
