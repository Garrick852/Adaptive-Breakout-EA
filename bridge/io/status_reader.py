"""EA -> AOS status channel (MI-003).

Reads the EA's decision status packet (``Common\\Files\\adaptivebo_status_<SYMBOL>.bin``,
a 104-byte SBridgePacket written by ``AosCommand::WriteStatus``) and exposes the
same staleness rule the EA enforces: the payload ``ts_sec`` (UTC epoch seconds)
is the clock — never the file mtime.

Status semantics (cmd_type / status / flags from the contract):
- cmd_type = EA decision: HOLD/BUY/SELL (BLOCK is reserved for AOS->EA).
- status  = OK / STALE (observation invalid) / ERROR (AOS command invalid) / LOCKED.
- flags   = override_valid (bit0) / risk_veto (bit1, local gate vetoed).
"""
from __future__ import annotations

import time
from pathlib import Path
from typing import Optional

from bridge.config import OBSERVATIONS_DIR
from bridge.contracts.sbridge_packet import ContractError, decode

STATUS_PREFIX = "adaptivebo_status_"
STATUS_SUFFIX = ".bin"

DEFAULT_MAX_AGE_SEC = 2  # mirrors the EA InpAosCmdStaleSec default


def status_path(symbol: str, status_dir: Optional[Path] = None) -> Path:
    base = status_dir if status_dir is not None else OBSERVATIONS_DIR
    if base is None:
        raise RuntimeError("OBSERVATIONS_DIR is not configured (set OBSERVATIONS_DIR or MT5_DATA_DIR).")
    return Path(base) / f"{STATUS_PREFIX}{symbol.upper()}{STATUS_SUFFIX}"


def read_status(symbol: str, status_dir: Optional[Path] = None) -> Optional[dict]:
    """Decode the EA status packet. None when absent; ContractError when invalid.

    The caller must treat None/invalid/stale as HOLD (never trade on it).
    """
    path = status_path(symbol, status_dir)
    if not path.exists():
        return None
    try:
        data = path.read_bytes()
    except OSError as exc:  # locked / transient read failure
        raise ContractError(f"could not read status {path}: {exc}") from exc
    status = decode(data)  # validates length/magic/version/CRC
    status["_source_file"] = str(path)
    return status


def is_stale_status(status: Optional[dict], max_age_sec: int = DEFAULT_MAX_AGE_SEC,
                    now_sec: Optional[int] = None) -> bool:
    """True when the status is missing or its payload ts_sec is older than max_age_sec.

    HOLD rule: consumers must treat True (or None) as 'no valid EA decision'.
    Uses the payload clock (UTC epoch seconds) — same boundary as the EA.
    """
    if not status:
        return True
    ts_sec = status.get("ts_sec")
    if not isinstance(ts_sec, int) or ts_sec <= 0:
        return True
    now = now_sec if now_sec is not None else int(time.time())
    return (now - ts_sec) > max_age_sec
