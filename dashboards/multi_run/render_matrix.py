import argparse
import pathlib
import random

import yaml


def render(cfg):
    random.seed(cfg.get("seeds", {}).get("python", 0))
    out = pathlib.Path("dashboards/glyphs/expected")
    out.mkdir(parents=True, exist_ok=True)
    for sym in cfg["symbols"]:
        (out / f"{sym}_demo.txt").write_text(f"glyph:{sym}:seed={cfg['seeds']['python']}\n")
    (out / "DriftDetected.txt").write_text("glyph:DriftDetected:demo\n")
    print("[dashboard] Rendered demo glyph placeholders.")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--config", required=True)
    args = ap.parse_args()
    with open(args.config) as f:
        cfg = yaml.safe_load(f)
    render(cfg)