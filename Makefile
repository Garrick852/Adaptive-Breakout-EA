.PHONY: setup lint test render glyphs ci package-mt5

setup:
	python -m pip install --upgrade pip
	pip install -r requirements.txt
	pip install pre-commit
	pre-commit install

lint:
	python -m ruff check python dashboards
	python -m mypy python --ignore-missing-imports

test:
	pytest -q

render:
	python dashboards/multi_run/render_matrix.py --config configs/demo/router_demo.yaml

glyphs: render
	pytest -q python/tests/test_glyphs.py

ci: setup lint test glyphs
	@echo "CI suite complete"

package-mt5:
	python3 scripts/package_mt5.py
	@echo "MT5 package ready at dist/mt5/"
