from pathlib import Path
from typing import Optional

from bridge.config import FILES_DIR, AI_SIGNAL_FILENAME, AI_SIGNAL_PER_SYMBOL, MT5_DATA_DIR

class BridgeSignalError(RuntimeError):
    pass

def get_signal_path(symbol: Optional[str] = None, per_symbol: bool = False) -> Path:
    if FILES_DIR is None or MT5_DATA_DIR is None:
        raise BridgeSignalError(
            "MT5_DATA_DIR is not configured. Set the MT5_DATA_DIR environment variable."
        )

    if per_symbol and symbol:
        filename = AI_SIGNAL_PER_SYMBOL.format(symbol=symbol.upper())
    else:
        filename = AI_SIGNAL_FILENAME

    return FILES_DIR / filename

def write_signal(signal: int, symbol: Optional[str] = None, per_symbol: bool = False) -> Path:
    if signal not in (-1, 0, 1):
        raise BridgeSignalError(f"Invalid signal {signal}, must be -1, 0, or 1")

    path = get_signal_path(symbol, per_symbol=per_symbol)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(str(signal) + "\n", encoding="utf-8")
    return path
