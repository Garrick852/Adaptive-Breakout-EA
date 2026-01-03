#!/usr/bin/env python3
import os
import shutil

# Source paths
SRC_EA = "eas/AdaptiveBreakoutAI/src"
SRC_CONFIGS = "configs"
SRC_DASHBOARDS = "dashboards"

# Target paths
TARGET_ROOT = "dist/mt5"
TARGET_EXPERTS = os.path.join(TARGET_ROOT, "MQL5/Experts/AdaptiveBreakoutAI")
TARGET_INCLUDE = os.path.join(TARGET_ROOT, "MQL5/Include/AdaptiveBreakoutAI")
TARGET_FILES = os.path.join(TARGET_ROOT, "MQL5/Files")

# Exclusion filters
EXCLUDE_CONFIGS = {"prop_firm.json", "demo.json"}
EXCLUDE_DASHBOARDS = {"glyphs/expected"}  # relative subpaths to skip

def ensure_dirs():
    for d in [TARGET_EXPERTS, TARGET_INCLUDE, TARGET_FILES]:
        os.makedirs(d, exist_ok=True)

def copy_ea_files():
    for f in os.listdir(SRC_EA):
        if f.endswith(".mq5"):
            shutil.copy(os.path.join(SRC_EA, f), TARGET_EXPERTS)
        elif f.endswith(".mqh"):
            shutil.copy(os.path.join(SRC_EA, f), TARGET_INCLUDE)

def copy_configs():
    if os.path.exists(SRC_CONFIGS):
        for root, _, files in os.walk(SRC_CONFIGS):
            rel_path = os.path.relpath(root, SRC_CONFIGS)
            target_dir = os.path.join(TARGET_FILES, "configs", rel_path)
            os.makedirs(target_dir, exist_ok=True)
            for f in files:
                if f in EXCLUDE_CONFIGS:
                    continue
                shutil.copy(os.path.join(root, f), target_dir)

def copy_dashboards():
    if os.path.exists(SRC_DASHBOARDS):
        for root, _, files in os.walk(SRC_DASHBOARDS):
            rel_path = os.path.relpath(root, SRC_DASHBOARDS)
            if any(rel_path.startswith(ex) for ex in EXCLUDE_DASHBOARDS):
                continue
            target_dir = os.path.join(TARGET_FILES, "dashboards", rel_path)
            os.makedirs(target_dir, exist_ok=True)
            for f in files:
                shutil.copy(os.path.join(root, f), target_dir)

def main():
    ensure_dirs()
    copy_ea_files()
    copy_configs()
    copy_dashboards()
    print("✅ MT5 package scaffolded at:", TARGET_ROOT)

if __name__ == "__main__":
    main()
