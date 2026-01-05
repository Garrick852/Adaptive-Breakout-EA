#!/usr/bin/env python3
import sys
from pathlib import Path
import json

CONFIG_DIR = Path("configs")

def fail(msg: str, code: int = 1):
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(code)

def validate_single_config(path: Path) -> bool:
    print(f"[INFO] Validating config: {path}")
    try:
        cfg = json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"[ERROR] Failed to parse JSON: {e}")
        return False

    ok = True

    def ck(cond, msg):
        nonlocal ok
        if not cond:
            print(f"[ERROR] {path.name}: {msg}")
            ok = False

    daily_loss = cfg.get("InpDailyLossStopPct", 0)
    max_dd     = cfg.get("InpMaxTotalDDPct", 0)
    risk_pct   = cfg.get("InpRiskPercentPerTrade", 0)

    ck(0 <= daily_loss <= 20, "InpDailyLossStopPct out of [0,20]")
    ck(0 <= max_dd <= 30, "InpMaxTotalDDPct out of [0,30]")
    ck(0 <= risk_pct <= 5, "InpRiskPercentPerTrade out of [0,5]")

    atr_period = cfg.get("InpATRPeriod", 0)
    ck(atr_period > 0, "InpATRPeriod must be > 0")

    return ok

def main():
    if not CONFIG_DIR.exists():
        print("[INFO] No configs directory; skipping.")
        sys.exit(0)

    all_ok = True
    for path in CONFIG_DIR.rglob("*.json"):
        if not validate_single_config(path):
            all_ok = False

    if not all_ok:
        fail("One or more EA configs failed validation")
    print("[OK] EA configs valid")
    sys.exit(0)

if __name__ == "__main__":
    main()
