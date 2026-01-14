import os
from pathlib import Path

# ...existing code...

# Optional: path to a custom EA log file inside MT5 Data Folder.
# You can have the EA write to MQL5\Files\adaptive_breakout_ea.log
EA_LOG_RELATIVE = Path("MQL5") / "Files" / "adaptive_breakout_ea.log"

EA_LOG_PATH = (
    (MT5_DATA_DIR / EA_LOG_RELATIVE) if MT5_DATA_DIR is not None else None
)
