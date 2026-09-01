from pathlib import Path
import os

# Base repo root
BASE_DIR = Path(__file__).resolve().parents[1]

# Config + schemas (if you want the bridge to read EA/router configs)
CONFIGS_DIR = BASE_DIR / "configs"

# MT5 integration
# Should be the same as in dashboards/backend/config/settings.py
MT5_DATA_DIR = Path(os.getenv("MT5_DATA_DIR", "")) if os.getenv("MT5_DATA_DIR") else None

FILES_DIR = MT5_DATA_DIR / "MQL5" / "Files" if MT5_DATA_DIR else None

# Feature file naming convention (for one symbol demo; generalize later)
FEATURE_FILE_PATTERN = "features_{symbol}.csv"

# MI-002: FILE_COMMON observation tap. Common\Files is a SIBLING of the
# terminal data dir (%APPDATA%\MetaQuotes\Terminal\Common\Files). Override
# with OBSERVATIONS_DIR if the terminal layout differs.
OBSERVATIONS_PREFIX = "adaptivebo_observations_"
OBSERVATIONS_SUFFIX = ".csv"
if os.getenv("OBSERVATIONS_DIR"):
    OBSERVATIONS_DIR = Path(os.getenv("OBSERVATIONS_DIR"))
elif MT5_DATA_DIR is not None:
    OBSERVATIONS_DIR = MT5_DATA_DIR.parent / "Common" / "Files"
else:
    OBSERVATIONS_DIR = None

# Signal file naming
AI_SIGNAL_FILENAME = "ai_signal.txt"                # global
AI_SIGNAL_PER_SYMBOL = "ai_signal_{symbol}.txt"     # per-symbol

# Loop settings
POLL_INTERVAL_SEC = float(os.getenv("BRIDGE_POLL_INTERVAL", "2.0"))  # seconds
MIN_UPDATE_INTERVAL_SEC = 1.0  # per-symbol minimum time between ML evaluations
