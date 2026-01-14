import json
import os
import sys

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIGS_DIR = os.path.join(BASE_DIR, "configs")

SRC_JSON = "ea_default.json"
DST_FLAT = "ea_runtime.cfg"

EA_KEYS = [
    "atr_period",
    "atr_mult_sl",
    "atr_mult_tp",
    "min_atr_filter",
    "box_mode",
    "box_lookback_bars",
    "time_from_hour",
    "time_to_hour",
    "breakout_buffer_pts",
    "require_close_beyond",
    "risk_percent_per_trade",
    "use_pending_orders",
    "use_atr_trail",
    "atr_trail_mult",
]

def main():
    src = os.path.join(CONFIGS_DIR, SRC_JSON)
    dst = os.path.join(CONFIGS_DIR, DST_FLAT)

    if not os.path.exists(src):
        print(f"[ERROR] Source config not found: {src}")
        sys.exit(1)

    with open(src, "r", encoding="utf-8") as f:
        cfg = json.load(f)

    lines = []
    for key in EA_KEYS:
        if key not in cfg:
            print(f"[WARN] Key '{key}' missing in {SRC_JSON}, skipping")
            continue
        v = cfg[key]
        lines.append(f"{key}={v}")

    with open(dst, "w", encoding="utf-8") as f:
        f.write("\n".join(str(line) for line in lines))

    print(f"[OK] Exported EA runtime config to {dst}")

if __name__ == "__main__":
    main()
