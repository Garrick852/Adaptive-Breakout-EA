#!/usr/bin/env python3
import os
import shutil
from pathlib import Path

# Source paths
SRC_EA = Path("eas/AdaptiveBreakoutAI/src")
SRC_CONFIGS = Path("configs")
SRC_DASHBOARDS = Path("dashboards")

# Target paths
TARGET_ROOT = Path("dist/mt5")
TARGET_EXPERTS = TARGET_ROOT / "MQL5/Experts/AdaptiveBreakoutAI"
TARGET_INCLUDE = TARGET_ROOT / "MQL5/Include/AdaptiveBreakoutAI"
TARGET_FILES = TARGET_ROOT / "MQL5/Files"
TARGET_CONFIGS = TARGET_FILES / "configs"
TARGET_DASHBOARDS = TARGET_FILES / "dashboards"

# Files to exclude from packaging
EXCLUDED_CONFIGS = {"prop_firm.json"}

def ensure_dirs():
    for d in [TARGET_EXPERTS, TARGET_INCLUDE, TARGET_FILES, TARGET_CONFIGS, TARGET_DASHBOARDS]:
        d.mkdir(parents=True, exist_ok=True)

def copy_ea_files():
    if not SRC_EA.exists():
        print(f"⚠️ Source EA path missing: {SRC_EA}")
        return
    for f in SRC_EA.iterdir():
        if f.suffix == ".mq5":
            shutil.copy(f, TARGET_EXPERTS)
        elif f.suffix == ".mqh":
            shutil.copy(f, TARGET_INCLUDE)

def copy_configs():
    if not SRC_CONFIGS.exists():
        print(f"⚠️ Config path missing: {SRC_CONFIGS}")
        return
    for f in SRC_CONFIGS.iterdir():
        if f.name in EXCLUDED_CONFIGS:
            print(f"⏭️ Skipping excluded config: {f.name}")
            continue
        if f.is_dir():
            # Preserve subfolders such as schema/
            shutil.copytree(f, TARGET_CONFIGS / f.name, dirs_exist_ok=True)
        elif f.is_file():
            shutil.copy(f, TARGET_CONFIGS)

def copy_dashboards():
    if not SRC_DASHBOARDS.exists():
        print(f"⚠️ Dashboards path missing: {SRC_DASHBOARDS}")
        return
    # Copy entire dashboards tree (includes glyphs/expected, json, etc.)
    shutil.copytree(SRC_DASHBOARDS, TARGET_DASHBOARDS, dirs_exist_ok=True)

def main():
    ensure_dirs()
    copy_ea_files()
    copy_configs()
    copy_dashboards()
    print(f"✅ MT5 package scaffolded at: {TARGET_ROOT}")

if __name__ == "__main__":
    main()
