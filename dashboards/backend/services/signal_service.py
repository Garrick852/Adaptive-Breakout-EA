from pathlib import Path
from typing import Optional

from dashboards.backend.config.settings import AI_SIGNAL_DIR, MT5_DATA_DIR
from dashboards.backend.models.signal import SignalRequest

class SignalWriteError(RuntimeError):
    pass

def get_signal_file_path(symbol: str, per_symbol: bool = False) -> Path:
    """
    Decide where to write the AI signal file.

    If per_symbol is False:
      -> <MT5_DATA_DIR>/MQL5/Files/ai_signal.txt
    If per_symbol is True:
      -> <MT5_DATA_DIR>/MQL5/Files/ai_signal_<symbol>.txt
    """
    if AI_SIGNAL_DIR is None or MT5_DATA_DIR is None:
        raise SignalWriteError(
            "MT5_DATA_DIR is not configured. Set the MT5_DATA_DIR environment variable "
            "to your MT5 terminal data path."
        )

    if per_symbol:
        filename = f"ai_signal_{symbol.upper()}.txt"
    else:
        filename = "ai_signal.txt"

    return AI_SIGNAL_DIR / filename

def write_signal(req: SignalRequest, per_symbol: bool = False) -> Path:
    """
    Write the signal to a file that the EA can read.

    Very simple format:
      First line: integer -1, 0, or 1
      (You can extend with timestamp/meta later)
    """
    path = get_signal_file_path(req.symbol, per_symbol=per_symbol)

    # Make sure directory exists
    path.parent.mkdir(parents=True, exist_ok=True)

    # For now, just write the raw signal on the first line
    # Optionally you can add timestamp or TTL as commented lines
    content_lines = [
        str(req.signal),
        # f"# ttl_seconds={req.ttl_seconds}",
    ]
    path.write_text("\n".join(content_lines), encoding="utf-8")

    return path
