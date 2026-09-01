"""Contract tests for the MI-003 AOS<->EA command/status channel.

Pins: atomic command writes (no .tmp left behind), 104-byte packets, the
payload-clock staleness rule (ts_sec, NOT file mtime) on BOTH channels, and
tamper rejection via the shared decoder.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.contracts.sbridge_packet import (  # noqa: E402
    CmdType,
    ContractError,
    PACKET_SIZE,
    encode,
)
from bridge.io.command_writer import command_path, write_command  # noqa: E402
from bridge.io.status_reader import (  # noqa: E402
    is_stale_status,
    read_status,
    status_path,
)


def test_write_command_is_exactly_104_bytes_and_atomic(tmp_path: Path):
    path = write_command("EURUSD", CmdType.BUY, out_dir=tmp_path, seq_id=1, ts_sec=1_752_998_400)
    data = path.read_bytes()
    assert len(data) == PACKET_SIZE == 104
    assert not path.with_suffix(path.suffix + ".tmp").exists()  # tmp cleaned up
    assert path.name == "adaptivebo_command_EURUSD.bin"


def test_command_roundtrip_via_shared_decoder(tmp_path: Path):
    ts = 1_752_998_400
    path = write_command("EURUSD", CmdType.SELL, out_dir=tmp_path, seq_id=7, ts_sec=ts)
    parsed = __import__("bridge.contracts.sbridge_packet", fromlist=["decode"]).decode(
        path.read_bytes()
    )
    assert parsed["cmd_type"] == CmdType.SELL
    assert parsed["seq_id"] == 7
    assert parsed["ts_sec"] == ts
    assert parsed["symbol"] == "EURUSD"


def test_command_payload_clock_staleness_not_mtime(tmp_path: Path):
    """A fresh mtime with an OLD payload ts_sec must still be stale (HOLD)."""
    now = int(time.time())
    path = write_command("EURUSD", CmdType.BUY, out_dir=tmp_path, seq_id=1, ts_sec=now - 60)
    # Touch the file so mtime is NOW — the payload clock must still say stale.
    path.touch()
    data = path.read_bytes()
    parsed = __import__("bridge.contracts.sbridge_packet", fromlist=["decode"]).decode(data)
    assert is_stale_status({"ts_sec": parsed["ts_sec"]}, max_age_sec=2, now_sec=now) is True


def test_status_roundtrip_and_staleness(tmp_path: Path):
    # Simulate the EA's status packet (same writer contract as the MQL5 side).
    now = int(time.time())
    pkt = encode({"cmd_type": CmdType.HOLD, "status": 0, "seq_id": 3, "ts_sec": now, "symbol": "EURUSD"})
    p = status_path("EURUSD", tmp_path)
    p.write_bytes(pkt)

    status = read_status("EURUSD", status_dir=tmp_path)
    assert status is not None
    assert status["cmd_type"] == CmdType.HOLD
    assert status["ts_sec"] == now
    assert is_stale_status(status, now_sec=now) is False
    assert is_stale_status(status, max_age_sec=2, now_sec=now + 5) is True  # payload clock


def test_status_missing_is_none_and_stale(tmp_path: Path):
    assert read_status("EURUSD", status_dir=tmp_path) is None
    assert is_stale_status(None) is True


def test_status_zero_ts_is_stale(tmp_path: Path):
    pkt = encode({"cmd_type": CmdType.HOLD, "ts_sec": 0, "symbol": "EURUSD"})
    p = status_path("EURUSD", tmp_path)
    p.write_bytes(pkt)
    status = read_status("EURUSD", status_dir=tmp_path)
    assert is_stale_status(status) is True


def test_tampered_status_rejected(tmp_path: Path):
    now = int(time.time())
    pkt = bytearray(encode({"cmd_type": CmdType.HOLD, "ts_sec": now, "symbol": "EURUSD"}))
    pkt[20] ^= 0xFF  # corrupt symbol payload -> CRC mismatch
    p = status_path("EURUSD", tmp_path)
    p.write_bytes(bytes(pkt))
    with pytest.raises(ContractError, match="crc"):
        read_status("EURUSD", status_dir=tmp_path)


def test_priority_constants():
    # BLOCK > HOLD > BUY/SELL is an EA-side semantic; pin the wire values so the
    # EA enum and the AOS CmdType can never drift apart.
    assert int(CmdType.HOLD) == 0
    assert int(CmdType.BUY) == 1
    assert int(CmdType.SELL) == 2
    assert int(CmdType.BLOCK) == 3
