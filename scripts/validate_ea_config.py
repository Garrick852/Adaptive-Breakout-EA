import json
import os
import sys

from jsonschema import Draft7Validator

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIGS_DIR = os.path.join(BASE_DIR, "configs")
SCHEMAS_DIR = os.path.join(CONFIGS_DIR, "schemas")

# Map: config filename -> (schema filename, human-readable label)
CONFIG_SCHEMA_MAP = {
    "ea_default.json":   ("ea.schema.json",      "EA default config"),
    "router_demo.json":  ("router.schema.json",  "Router config"),
    "risk_presets.json": ("risk.schema.json",    "Risk presets"),
    "symbols_map.json":  ("symbols.schema.json", "Symbols map"),
    # Uncomment when you have a schema for sessions:
    # "session_windows.json": ("session.schema.json", "Session windows"),
}

def load_json(path):
    if not os.path.exists(path):
        print(f"[ERROR] File not found: {path}")
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[ERROR] Failed to parse {path}: {e}")
        return None

def validate_config(config_name, schema_name, label):
    cfg_path = os.path.join(CONFIGS_DIR, config_name)
    schema_path = os.path.join(SCHEMAS_DIR, schema_name)

    schema = load_json(schema_path)
    if schema is None:
        return False

    data = load_json(cfg_path)
    if data is None:
        return False

    validator = Draft7Validator(schema)
    errors = sorted(validator.iter_errors(data), key=lambda e: e.path)

    if errors:
        print(f"[ERROR] {label} ({config_name}) failed validation against {schema_name}:")
        for err in errors:
            # Path like "presets -> PROP_CHALLENGE_P1 -> risk_percent"
            path = " -> ".join(str(p) for p in err.path) or "<root>"
            print(f"  - at {path}: {err.message}")
        return False

    print(f"[OK] {label} ({config_name}) passed validation")
    return True

def main():
    all_good = True

    for cfg, (schema, label) in CONFIG_SCHEMA_MAP.items():
        if not validate_config(cfg, schema, label):
            all_good = False

    if not all_good:
        sys.exit(1)

if __name__ == "__main__":
    main()
