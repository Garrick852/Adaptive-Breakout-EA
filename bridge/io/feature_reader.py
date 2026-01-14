from pathlib import Path
from typing import Optional, Dict

from bridge.config import FILES_DIR, FEATURE_FILE_PATTERN, MT5_DATA_DIR

class FeatureReadError(RuntimeError):
    pass

def get_feature_path(symbol: str) -> Path:
    if FILES_DIR is None or MT5_DATA_DIR is None:
        raise FeatureReadError(
            "MT5_DATA_DIR is not configured. Set MT5_DATA_DIR env var."
        )
    filename = FEATURE_FILE_PATTERN.format(symbol=symbol.upper())
    return FILES_DIR / filename

def read_latest_features(symbol: str) -> Optional[Dict[str, float]]:
    """
    Read the last line from features_<symbol>.csv and parse into a dict.
    CSV format example:
      timestamp,close,atr,box_upper,box_lower
    """
    path = get_feature_path(symbol)
    if not path.exists():
        return None

    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = [line for line in text.splitlines() if line.strip()]
    if not lines:
        return None

    header = lines[0].split(",")
    last = lines[-1].split(",")

    if len(header) != len(last):
        raise FeatureReadError(f"Header/row length mismatch in {path}")

    data = dict(zip(header, last))
    # Convert numeric fields where possible
    out: Dict[str, float] = {}
    for k, v in data.items():
        v = v.strip()
        if k == "timestamp":
            # keep raw string or handle separately
            continue
        try:
            out[k] = float(v)
        except ValueError:
            continue
    return out
