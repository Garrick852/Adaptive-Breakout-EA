"""Contract tests for the MI-002 observation tap reader (AOS side).

Pins the tap file contract: header + single data line, training-contract
feature order, ts_ms/seq_id presence, stale semantics (missing/old =>
stale => HOLD), and parse-failure behavior.
"""
from __future__ import annotations

import sys
import time
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.io.observation_reader import (  # noqa: E402
    FEATURE_COLUMNS,
    OBSERVATION_COLUMNS,
    ObservationReadError,
    is_stale,
    read_latest_observation,
)

# Training-contract order (must never change).
EXPECTED_FEATURES = [
    "regime_bias",
    "adx_norm",
    "ema_crossover",
    "range_width_frac",
    "range_position",
    "drawdown_fraction",
]

HEADER = "ts_ms,seq_id,symbol,timeframe,regime_bias,adx_norm,ema_crossover,range_width_frac,range_position,drawdown_fraction"


def _write_tap(tmp_path: Path, symbol: str, line: str) -> Path:
    p = tmp_path / f"adaptivebo_observations_{symbol}.csv"
    p.write_text(HEADER + "\n" + line + "\n", encoding="utf-8")
    return p


def test_feature_order_matches_training_contract():
    assert FEATURE_COLUMNS == EXPECTED_FEATURES


def test_read_latest_observation_parses_all_columns(tmp_path: Path):
    now_ms = int(time.time() * 1000)
    p = _write_tap(
        tmp_path,
        "EURUSD",
        f"{now_ms},7,EURUSD,PERIOD_H1,1.0,0.25,-0.1,2.5,0.3,0.012",
    )
    obs = read_latest_observation("EURUSD", observations_dir=tmp_path)
    assert obs is not None
    assert obs["ts_ms"] == now_ms
    assert obs["seq_id"] == 7
    assert obs["symbol"] == "EURUSD"
    assert obs["timeframe"] == "PERIOD_H1"
    assert obs["regime_bias"] == 1.0
    assert obs["adx_norm"] == 0.25
    assert obs["ema_crossover"] == -0.1
    assert obs["range_width_frac"] == 2.5
    assert obs["range_position"] == 0.3
    assert obs["drawdown_fraction"] == 0.012
    assert obs["_source_file"] == str(p)


def test_missing_file_returns_none(tmp_path: Path):
    assert read_latest_observation("EURUSD", observations_dir=tmp_path) is None


def test_header_only_returns_none(tmp_path: Path):
    p = tmp_path / "adaptivebo_observations_EURUSD.csv"
    p.write_text(HEADER + "\n", encoding="utf-8")
    assert read_latest_observation("EURUSD", observations_dir=tmp_path) is None


def test_header_mismatch_raises(tmp_path: Path):
    p = tmp_path / "adaptivebo_observations_EURUSD.csv"
    p.write_text("a,b,c\n1,2,3\n", encoding="utf-8")
    with pytest.raises(ObservationReadError, match="header mismatch"):
        read_latest_observation("EURUSD", observations_dir=tmp_path)


def test_bad_row_length_raises(tmp_path: Path):
    _write_tap(tmp_path, "EURUSD", "1,2,3,4,5,6,7,8,9")
    with pytest.raises(ObservationReadError, match="row length"):
        read_latest_observation("EURUSD", observations_dir=tmp_path)


def test_non_numeric_feature_raises(tmp_path: Path):
    now_ms = int(time.time() * 1000)
    _write_tap(tmp_path, "EURUSD", f"{now_ms},7,EURUSD,PERIOD_H1,abc,0.25,0,0,0,0")
    with pytest.raises(ObservationReadError, match="non-numeric"):
        read_latest_observation("EURUSD", observations_dir=tmp_path)


def test_is_stale_missing_or_old(tmp_path: Path):
    now_ms = int(time.time() * 1000)
    assert is_stale(None) is True  # no observation => stale => HOLD

    fresh = read_latest_observation(
        "EURUSD",
        observations_dir=_write_tap(
            tmp_path, "EURUSD", f"{now_ms},1,EURUSD,PERIOD_H1,0,0,0,0,0.5,0"
        ).parent,
    )
    assert is_stale(fresh, now_ms=now_ms) is False

    old = read_latest_observation(
        "EURUSD",
        observations_dir=_write_tap(
            tmp_path, "EURUSD", f"{now_ms - 60_000},1,EURUSD,PERIOD_H1,0,0,0,0,0.5,0"
        ).parent,
    )
    assert is_stale(old, max_age_ms=2500, now_ms=now_ms) is True


def test_zero_ts_is_stale(tmp_path: Path):
    obs = read_latest_observation(
        "EURUSD",
        observations_dir=_write_tap(tmp_path, "EURUSD", "0,1,EURUSD,PERIOD_H1,0,0,0,0,0.5,0").parent,
    )
    assert is_stale(obs) is True
