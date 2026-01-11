import os
import json
import sys
import io

# Force UTF-8 output even on Windows
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

REQUIRED_KEYS = {
    "ea_config.json": ["strategy", "risk", "parameters"],
    "router_config.json": ["routes", "default"]
}

def validate_file(path, required_keys):
    if not os.path.exists(path):
        print(f"[ERROR] Config file not found: {path}")
        return False

    try:
        with open(path, "r") as f:
            data = json.load(f)
    except Exception as e:
        print(f"[ERROR] Failed to parse {path}: {e}")
        return False

    missing = [key for key in required_keys if key not in data]
    if missing:
        print(f"[ERROR] {path} missing keys: {', '.join(missing)}")
        return False

    # ASCII-safe success marker
    print(f"[OK] {path} passed validation")
    return True

def main():
    configs_dir = "configs"
    all_good = True

    for filename, required in REQUIRED_KEYS.items():
        cfg = os.path.join(configs_dir, filename)
        if not validate_file(cfg, required):
            all_good = False

    if not all_good:
        sys.exit(1)

if __name__ == "__main__":
    main()
