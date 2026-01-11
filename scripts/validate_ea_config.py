#!/usr/bin/env python3
"""
Simple EA config validator for GitHub Actions CI.
Checks JSON config files for required keys.
"""

import json
import sys
import os

# List of config files to validate
CONFIG_FILES = [
    "configs/ea_config.json",
    "configs/router_config.json",
]

# Define required keys for each config
REQUIRED_KEYS = {
    "configs/ea_config.json": ["strategy", "risk", "parameters"],
    "configs/router_config.json": ["routes", "default"],
}

def validate_file(path, required_keys):
    if not os.path.exists(path):
        print(f"ERROR: Config file not found: {path}")
        return False

    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"ERROR: Failed to parse {path}: {e}")
        return False

    ok = True
    for key in required_keys:
        if key not in data:
            print(f"ERROR: Missing key '{key}' in {path}")
            ok = False

    if ok:
        print(f"✓ {path} passed validation")
    return ok

def main():
    all_ok = True
    for cfg in CONFIG_FILES:
        required = REQUIRED_KEYS.get(cfg, [])
        if not validate_file(cfg, required):
            all_ok = False

    if not all_ok:
        sys.exit(1)  # fail CI
    else:
        print("All configs validated successfully.")

if __name__ == "__main__":
    main()
