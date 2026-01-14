from pathlib import Path

# Base directories for the project
BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
CONFIGS_DIR = BASE_DIR / "configs"
SCHEMAS_DIR = CONFIGS_DIR / "schema"

# MT5 Data directory (optional, may not exist in dev container)
MT5_DATA_DIR = None  # Can be set via environment variable if needed

# AI Signal directory for writing signal files
AI_SIGNAL_DIR = BASE_DIR / "Files"

# Optional: path to a custom EA log file inside MT5 Data Folder.
# You can have the EA write to MQL5\Files\adaptive_breakout_ea.log
EA_LOG_RELATIVE = Path("MQL5") / "Files" / "adaptive_breakout_ea.log"

EA_LOG_PATH = (
    (MT5_DATA_DIR / EA_LOG_RELATIVE) if MT5_DATA_DIR is not None else None
)
