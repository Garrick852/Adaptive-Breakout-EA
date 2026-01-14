import os
from pathlib import Path

# Base repo directory (two levels up from this file)
BASE_DIR = Path(__file__).resolve().parents[2]

CONFIGS_DIR = BASE_DIR / "configs"
SCHEMAS_DIR = CONFIGS_DIR / "schemas"

# MT5 data directory (for Files/, Experts/, etc.) - override via env if needed
MT5_DATA_DIR = Path(os.getenv("MT5_DATA_DIR", "")) if os.getenv("MT5_DATA_DIR") else None

# Where ai_signal.txt (or per-symbol variants) should be written, under MT5 Files directory
AI_SIGNAL_DIR = MT5_DATA_DIR / "MQL5" / "Files" if MT5_DATA_DIR else None
