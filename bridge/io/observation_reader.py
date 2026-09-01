"""Read the MI-002 6-feature observation tap (FILE_COMMON CSV, atomic replace).

The EA (`observation_tap.mqh`) keeps ONE file per symbol in
``Common\\Files\\adaptivebo_observations_<SYMBOL>.csv`` with a header line and
exactly one data line (the latest observation), replaced atomically. Columns
match the AuraArc training contract (names AND order):

    ts_ms, seq_id, symbol, timeframe,
    regime_bias, adx_norm, ema_crossover, range_width_frac, range_position,
    drawdown_fraction

Semantics:
- file missing           -> None (no observation yet)
- header/data mismatch   -> ObservationReadError (parse failure)
- stale observation      -> is_stale() True (ts_ms older than max_age_ms)
- any of the above means the EA-side gate is in HOLD: consumers MUST NOT trade
  on a None/error/stale observation.
"""
from __future__ import annotations

import csv
import io
import time
from pathlib import Path
from typing import Dict, Optional

from bridge.config import OBSERVATIONS_DIR, OBSERVATIONS_PREFIX, OBSERVATIONS_SUFFIX

OBSERVATION_COLUMNS = [
    "ts_ms",
    "seq_id",
    "symbol",
    "timeframe",
    "regime_bias",
    "adx_norm",
    "ema_crossover",
    "range_width_frac",
    "range_position",
    "drawdown_fraction",
]
FEATURE_COLUMNS = OBSERVATION_COLUMNS[4:]  # the 6-feature training contract

DEFAULT_MAX_AGE_MS = 2500  # mirrors the EA InpTapStaleMs default


class ObservationReadError(RuntimeError):
    """Raised on a structurally invalid tap file (header/row mismatch)."""


def observation_path(symbol: str, observations_dir: Optional[Path] = None) -> Path:
    base = observations_dir if observations_dir is not None else OBSERVATIONS_DIR
    if base is None:
        raise ObservationReadError(
            "OBSERVATIONS_DIR is not configured. Set OBSERVATIONS_DIR or MT5_DATA_DIR."
        )
    return Path(base) / f"{OBSERVATIONS_PREFIX}{symbol.upper()}{OBSERVATIONS_SUFFIX}"


def read_latest_observation(
    symbol: str, observations_dir: Optional[Path] = None
) -> Optional[Dict]:
    """Return the latest observation as a dict, or None when no tap file exists.

    Raises ObservationReadError on a malformed file (header mismatch / bad row).
    """
    path = observation_path(symbol, observations_dir)
    if not path.exists():
        return None
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:  # locked or transient read failure
        raise ObservationReadError(f"could not read tap {path}: {exc}") from exc

    lines = [ln for ln in text.splitlines() if ln.strip()]
    if len(lines) < 2:
        return None  # header only / empty -> no observation yet

    header = next(csv.reader(io.StringIO(lines[0])))
    if header != OBSERVATION_COLUMNS:
        raise ObservationReadError(
            f"tap header mismatch in {path}: expected {OBSERVATION_COLUMNS}, got {header}"
        )

    row = next(csv.reader(io.StringIO(lines[-1])))
    if len(row) != len(OBSERVATION_COLUMNS):
        raise ObservationReadError(
            f"tap row length {len(row)} != {len(OBSERVATION_COLUMNS)} in {path}"
        )

    def _num(value: str, name: str) -> float:
        try:
            return float(value)
        except ValueError as exc:
            raise ObservationReadError(
                f"non-numeric {name!r} value {value!r} in {path}"
            ) from exc

    obs: Dict = {}
    for name, value in zip(OBSERVATION_COLUMNS, row):
        if name in ("ts_ms", "seq_id"):
            obs[name] = int(_num(value, name))
        elif name in ("symbol", "timeframe"):
            obs[name] = value.strip()
        else:
            obs[name] = _num(value, name)
    obs["_source_file"] = str(path)
    return obs


def is_stale(obs: Optional[Dict], max_age_ms: int = DEFAULT_MAX_AGE_MS,
             now_ms: Optional[int] = None) -> bool:
    """True when the observation is missing or its ts_ms is older than max_age_ms.

    HOLD rule: consumers must treat True (or None) as 'no valid observation'.
    """
    if not obs:
        return True
    ts_ms = obs.get("ts_ms")
    if not isinstance(ts_ms, int) or ts_ms <= 0:
        return True
    now = now_ms if now_ms is not None else int(time.time() * 1000)
    return (now - ts_ms) > max_age_ms
