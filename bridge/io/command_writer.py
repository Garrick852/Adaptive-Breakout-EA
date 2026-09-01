"""AOS -> EA command channel (MI-003).

Writes the 104-byte SBridgePacket command file that the EA consumes
(``Common\\Files\\adaptivebo_command_<SYMBOL>.bin``) with an atomic replace
(tmp -> os.replace), so the EA never observes a half-written command.

Staleness contract: the command's ``ts_sec`` PAYLOAD field (UTC epoch seconds)
is the clock both sides use — never the file mtime. The EA treats a command
older than its stale window (default 2 s) as UNKNOWN => HOLD.
"""
from __future__ import annotations

import os
import time
from pathlib import Path
from typing import Optional

from bridge.config import OBSERVATIONS_DIR
from bridge.contracts.sbridge_packet import CmdType, PACKET_SIZE, encode

COMMAND_PREFIX = "adaptivebo_command_"
COMMAND_SUFFIX = ".bin"

_seq_counter = 0


def _next_seq() -> int:
    global _seq_counter
    _seq_counter = (_seq_counter + 1) & 0xFFFFFFFF
    return _seq_counter


def command_path(symbol: str, out_dir: Optional[Path] = None) -> Path:
    base = out_dir if out_dir is not None else OBSERVATIONS_DIR
    if base is None:
        raise RuntimeError("OBSERVATIONS_DIR is not configured (set OBSERVATIONS_DIR or MT5_DATA_DIR).")
    return Path(base) / f"{COMMAND_PREFIX}{symbol.upper()}{COMMAND_SUFFIX}"


def write_command(
    symbol: str,
    cmd_type: int,
    out_dir: Optional[Path] = None,
    seq_id: Optional[int] = None,
    ts_sec: Optional[int] = None,
    flags: int = 0,
) -> Path:
    """Write the AOS command packet atomically. Returns the target path."""
    path = command_path(symbol, out_dir)
    data = encode(
        {
            "cmd_type": int(cmd_type),
            "flags": flags,
            "seq_id": _next_seq() if seq_id is None else int(seq_id),
            "ts_sec": int(time.time()) if ts_sec is None else int(ts_sec),
            "symbol": symbol,
        }
    )
    if len(data) != PACKET_SIZE:
        raise RuntimeError(f"encoded command is {len(data)} bytes, contract is {PACKET_SIZE}")
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_bytes(data)
    os.replace(tmp, path)
    return path


def main() -> int:  # pragma: no cover - manual tool
    import argparse

    ap = argparse.ArgumentParser(description="Write an AOS command packet (MI-003)")
    ap.add_argument("--symbol", required=True)
    ap.add_argument("--cmd", type=int, choices=[0, 1, 2, 3], default=0,
                    help="0=HOLD 1=BUY 2=SELL 3=BLOCK")
    ap.add_argument("--out", default=None, help="FILE_COMMON dir override")
    args = ap.parse_args()
    path = write_command(args.symbol, args.cmd, out_dir=Path(args.out) if args.out else None)
    print(f"[MI-003] command written -> {path} (cmd={args.cmd})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
