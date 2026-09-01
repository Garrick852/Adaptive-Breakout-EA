"""Tests for the Option-1 HITL status notifier (MI-003 status -> Telegram).

Pins: snapshotting (present/fields/stale), state-change-driven alerting
(no spam on unchanged state), escalation/STALE/CHANNEL-DOWN messages, and the
fail-closed sender (no token => no-op, never touches the network).
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.contracts.sbridge_packet import CmdType, encode  # noqa: E402
from bridge.monitor.status_notifier import (  # noqa: E402
    Snapshot,
    alert_message,
    send_telegram,
    take_snapshot,
)
from bridge.io.status_reader import status_path  # noqa: E402


def _write_status(tmp_path: Path, symbol: str, cmd: int, status: int, flags: int = 0,
                  ts_sec: int | None = None) -> Path:
    p = status_path(symbol, tmp_path)
    p.write_bytes(
        encode({"cmd_type": cmd, "status": status, "flags": flags,
                "ts_sec": ts_sec if ts_sec is not None else int(time.time()),
                "symbol": symbol})
    )
    return p


def test_snapshot_missing_file(tmp_path: Path):
    snap = take_snapshot("EURUSD", status_dir=tmp_path)
    assert snap.present is False
    assert snap.stale is True


def test_snapshot_parses_packet(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.BUY, 0, flags=0, ts_sec=now)
    snap = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    assert snap.present is True
    assert snap.cmd_type == CmdType.BUY
    assert snap.status == 0
    assert snap.stale is False


def test_snapshot_stale_uses_payload_clock(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now - 60)
    snap = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    assert snap.stale is True  # old payload ts, fresh mtime => stale


def test_no_alert_when_nothing_changed(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now)
    cur = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    assert alert_message(None, cur) is None          # healthy first sighting
    assert alert_message(cur, cur) is None           # unchanged => no spam


def test_alert_on_decision_change(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now)
    prev = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    _write_status(tmp_path, "EURUSD", CmdType.BUY, 0, ts_sec=now)
    cur = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    msg = alert_message(prev, cur)
    assert msg is not None and "decision=BUY" in msg


def test_alert_on_escalation_block(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now)
    prev = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    _write_status(tmp_path, "EURUSD", CmdType.BLOCK, 3, flags=2, ts_sec=now)  # LOCKED + risk_veto
    cur = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    msg = alert_message(prev, cur)
    assert msg is not None and "ESCALATION/LOCKDOWN" in msg and "risk_veto" in msg


def test_alert_on_stale(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now)
    prev = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now - 60)
    cur = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    msg = alert_message(prev, cur)
    assert msg is not None and "STALE" in msg


def test_alert_on_channel_down(tmp_path: Path):
    now = int(time.time())
    _write_status(tmp_path, "EURUSD", CmdType.HOLD, 0, ts_sec=now)
    prev = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    (status_path("EURUSD", tmp_path)).unlink()
    cur = take_snapshot("EURUSD", status_dir=tmp_path, now_sec=now)
    msg = alert_message(prev, cur)
    assert msg is not None and "CHANNEL DOWN" in msg


def test_send_telegram_no_token_is_noop():
    # No token/chat => no-op; must NOT raise and must not touch the network.
    assert send_telegram("test", token="", chat_id="") is False
