import os
import shutil
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(BASE_DIR, "eas", "AdaptiveBreakoutAI", "src")
CONFIGS_DIR = os.path.join(BASE_DIR, "configs")

# Output package dir (e.g. for deploy / zipping)
DIST_DIR = os.path.join(BASE_DIR, "dist", "mt5_package")
EXPERTS_SUBDIR = os.path.join(DIST_DIR, "MQL5", "Experts", "AdaptiveBreakoutAI")
FILES_SUBDIR = os.path.join(DIST_DIR, "MQL5", "Files")

def clean_dir(path):
    if os.path.exists(path):
        shutil.rmtree(path)
    os.makedirs(path, exist_ok=True)

def main():
    # Prepare directories
    clean_dir(EXPERTS_SUBDIR)
    os.makedirs(FILES_SUBDIR, exist_ok=True)

    # Copy main EA
    ea_src = os.path.join(SRC_DIR, "AdaptiveBreakoutAI.mq5")
    if not os.path.exists(ea_src):
        print(f"[ERROR] EA source not found: {ea_src}")
        sys.exit(1)
    shutil.copy2(ea_src, EXPERTS_SUBDIR)

    # Copy all .mqh modules
    for fname in os.listdir(SRC_DIR):
        if fname.lower().endswith(".mqh"):
            shutil.copy2(os.path.join(SRC_DIR, fname), EXPERTS_SUBDIR)

    # Copy runtime config if present
    runtime_cfg = os.path.join(CONFIGS_DIR, "ea_runtime.cfg")
    if os.path.exists(runtime_cfg):
        shutil.copy2(runtime_cfg, FILES_SUBDIR)
    else:
        print("[WARN] ea_runtime.cfg not found; EA will use built-in defaults")

    print(f"[OK] Packaged MT5 EA into {DIST_DIR}")

if __name__ == "__main__":
    main()
