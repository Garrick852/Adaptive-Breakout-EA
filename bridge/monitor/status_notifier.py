"""Option-1 HITL notifier: watches the EA status packets -> Telegram.

The pilot's HITL mode (docs/PILOT_RUN_CHECKLIST.md §4, Option 1): this watcher
polls ``Common\\Files\\adaptivebo_status_<SYMBOL>.bin`` (the MI-003 status
packets the EA writes), detects NOTABLE STATE CHANGES (decision change,
BLOCK/LOCKED escalation, STALE/ERROR status, channel down/stale), and sends a
Telegram message through the standard Bot API (same contract as the cosmic
``ops/telegram/service.py`` ``AuraArcBot.send_message``).

Guarantees:
- state-change driven (no per-poll spam); the EA's status writer is itself
  throttled 1 Hz / immediate-on-change, so polling at 5 s sees every change.
- READ-ONLY over the EA files: the notifier never writes to FILE_COMMON and
  can never influence the EA.
- fail-closed sender: no ``TELEGRAM_BOT_TOKEN`` => no-op (dry-run friendly);
  send failures are logged and never crash the loop.

Usage (trading machine):
    set TELEGRAM_BOT_TOKEN=... TELEGRAM_CHAT_ID=...   # optional: OBSERVATIONS_DIR
    python -m bridge.monitor.status_notifier --symbol EURUSD --watch
    python -m bridge.monitor.status_notifier --symbol EURUSD --once   # one-shot
"""
from __future__ import annotations

import argparse
import json
import logging
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional, Tuple

from bridge.config import OBSERVATIONS_DIR
from bridge.contracts.sbridge_packet import CmdType, Status
from bridge.io.status_reader import is_stale_status, read_status, status_path

logger = logging.getLogger("AdaptiveBO.Notifier")

TELEGRAM_API = "https://api.telegram.org/bot{token}/{method}"
TOKEN = os.getenv("TELEGRAM_BOT_TOKEN", "")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID", "")
POLL_INTERVAL_SEC = float(os.getenv("ADAPTIVEBO_NOTIFY_INTERVAL", "5.0"))
STATUS_MAX_AGE_SEC = int(os.getenv("ADAPTIVEBO_STATUS_MAX_AGE_SEC", "2"))

_CMD_NAMES = {0: "HOLD", 1: "BUY", 2: "SELL", 3: "BLOCK"}
_STATUS_NAMES = {0: "OK", 1: "STALE", 2: "ERROR", 3: "LOCKED"}


@dataclass(frozen=True)
class Snapshot:
    """Read-only view of one EA status packet (or its absence)."""

    symbol: str
    present: bool
    cmd_type: Optional[int]
    status: Optional[int]
    flags: int
    stale: bool
    ts_sec: Optional[int]

    def key(self) -> Tuple:
        return (self.present, self.cmd_type, self.status, self.flags, self.stale)


def take_snapshot(symbol: str, status_dir: Optional[Path] = None,
                  now_sec: Optional[int] = None) -> Snapshot:
    """Snapshot the current status packet. present=False when the file is absent."""
    path = status_path(symbol, status_dir)
    if not path.exists():
        return Snapshot(symbol, present=False, cmd_type=None, status=None, flags=0,
                        stale=True, ts_sec=None)
    status = read_status(symbol, status_dir=status_dir)
    if status is None:  # present but unreadable/invalid -> treated as down
        return Snapshot(symbol, present=False, cmd_type=None, status=None, flags=0,
                        stale=True, ts_sec=None)
    stale = is_stale_status(status, max_age_sec=STATUS_MAX_AGE_SEC, now_sec=now_sec)
    return Snapshot(
        symbol=symbol,
        present=True,
        cmd_type=int(status.get("cmd_type")),
        status=int(status.get("status")),
        flags=int(status.get("flags")),
        stale=stale,
        ts_sec=status.get("ts_sec"),
    )


def alert_message(prev: Optional[Snapshot], cur: Snapshot) -> Optional[str]:
    """Return a Telegram message when the change is notable, else None.

    State-change driven: no message when nothing notable changed. A None/absent
    previous snapshot (startup) does NOT emit a message for a healthy state.
    """
    if prev is None:
        if not cur.present or cur.stale:
            return _fmt(symbol=cur.symbol, line="CHANNEL DOWN/STALE at startup")
        return None  # first healthy sighting: stay quiet

    if prev.key() == cur.key():
        return None  # nothing changed

    if not cur.present:
        return _fmt(cur.symbol, "CHANNEL DOWN - status file missing")

    if cur.stale:
        return _fmt(cur.symbol, f"STATUS STALE (ts_sec={cur.ts_sec}) - EA not reporting")

    cmd = _CMD_NAMES.get(cur.cmd_type, str(cur.cmd_type))
    st = _STATUS_NAMES.get(cur.status, str(cur.status))
    parts = [f"decision={cmd}", f"status={st}"]
    if cur.cmd_type == int(CmdType.BLOCK):
        parts.append("ESCALATION/LOCKDOWN (4.5% cap or commanded BLOCK)")
    if cur.flags & 2:  # SB_FLAG_RISK_VETO
        parts.append("risk_veto")
    if cur.flags & 1:  # SB_FLAG_OVERRIDE_VALID
        parts.append("override_valid")
    return _fmt(cur.symbol, " | ".join(parts))


def _fmt(symbol: str, line: str) -> str:
    return f"[AdaptiveBO:{symbol}] {line}"


def send_telegram(text: str, token: str = TOKEN, chat_id: str = CHAT_ID) -> bool:
    """Standard Bot API sendMessage. No token => no-op (never touches the network)."""
    if not token or not chat_id:
        logger.debug("send_telegram skipped (no token/chat_id): %s", text)
        return False
    url = TELEGRAM_API.format(token=token, method="sendMessage")
    data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
    try:
        req = urllib.request.Request(url, data=data)
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read().decode()) is not None
    except (urllib.error.URLError, OSError, json.JSONDecodeError) as exc:
        logger.error("Telegram sendMessage failed: %s", exc)
        return False


def watch(symbols, status_dir=None, poll_interval: float = POLL_INTERVAL_SEC,
          dry_run: bool = False, once: bool = False) -> int:
    """Poll loop: emit alerts on notable changes. Returns 0."""
    last: Dict[str, Optional[Snapshot]] = {}
    while True:
        for symbol in symbols:
            cur = take_snapshot(symbol, status_dir=status_dir)
            msg = alert_message(last.get(symbol), cur)
            if msg is not None:
                if dry_run:
                    print(f"[dry-run] {msg}")
                else:
                    send_telegram(msg)
            last[symbol] = cur
        if once:
            return 0
        time.sleep(max(0.5, poll_interval))


def main() -> int:
    ap = argparse.ArgumentParser(description="AdaptiveBO Option-1 HITL notifier (MI-003 status -> Telegram)")
    ap.add_argument("--symbols", nargs="*", default=["EURUSD"], help="symbols to watch")
    ap.add_argument("--watch", action="store_true", help="poll loop (default: one-shot)")
    ap.add_argument("--interval", type=float, default=POLL_INTERVAL_SEC, help="poll seconds")
    ap.add_argument("--out", default=None, help="FILE_COMMON dir override (default: OBSERVATIONS_DIR)")
    ap.add_argument("--dry-run", action="store_true", help="print alerts instead of sending")
    args = ap.parse_args()
    status_dir = Path(args.out) if args.out else None
    if status_dir is None and OBSERVATIONS_DIR is None:
        print("OBSERVATIONS_DIR not configured; pass --out <Common\\Files>")
        return 1
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(name)s %(levelname)s %(message)s")
    return watch(args.symbols, status_dir=status_dir, poll_interval=args.interval,
                 dry_run=args.dry_run, once=not args.watch)


if __name__ == "__main__":
    raise SystemExit(main())
