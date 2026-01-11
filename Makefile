.PHONY:  mt5-build
mt5-build:
	python scripts/ci_mt5_build.py

.PHONY: validate-ea-configs
validate-ea-configs:
	python scripts/validate_ea_config. py

.PHONY: ci-ea
ci-ea: validate-ea-configs mt5-build
