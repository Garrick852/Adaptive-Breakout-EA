"""Contract tests for the MI-005 WFO fitness formula.

Pins the formula, the epsilon floor, the min-trades gate, the 4.5% cap
rejection (parity with the MI-004 escalation rail), and fail-closed behavior
on invalid stats.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.contracts.wfo_fitness import (  # noqa: E402
    EPSILON_DD,
    MAX_DD_CAP,
    MIN_TRADES,
    fitness,
)


def test_formula_basic():
    # (2.0 * 1.5) / 0.02 = 150.0
    assert fitness(pf=2.0, rf=1.5, max_dd=0.02, trades=50) == pytest.approx(150.0)


def test_epsilon_floor_prevents_explosion():
    # max_dd 0 -> denominator = EPSILON_DD (never 0, never infinity).
    assert fitness(pf=2.0, rf=1.0, max_dd=0.0, trades=50) == pytest.approx(2.0 / EPSILON_DD)
    assert fitness(pf=2.0, rf=1.0, max_dd=0.0, trades=50) < 1e9


def test_min_trades_gate():
    assert fitness(pf=2.0, rf=1.0, max_dd=0.02, trades=MIN_TRADES - 1) == -1.0
    assert fitness(pf=2.0, rf=1.0, max_dd=0.02, trades=MIN_TRADES) > 0.0


def test_cap_rejection_same_boundary_as_live_rail():
    assert MAX_DD_CAP == 0.045  # parity with escalation.mqh
    assert fitness(pf=2.0, rf=1.0, max_dd=0.0449, trades=50) > 0.0
    assert fitness(pf=2.0, rf=1.0, max_dd=0.0450, trades=50) == -1.0
    assert fitness(pf=2.0, rf=1.0, max_dd=0.10, trades=50) == -1.0


def test_fail_closed_on_invalid_stats():
    assert fitness(pf=math.nan, rf=1.0, max_dd=0.02, trades=50) == -1.0
    assert fitness(pf=2.0, rf=math.inf, max_dd=0.02, trades=50) == -1.0
    assert fitness(pf=0.0, rf=1.0, max_dd=0.02, trades=50) == -1.0
    assert fitness(pf=2.0, rf=0.0, max_dd=0.02, trades=50) == -1.0
    assert fitness(pf=-1.0, rf=1.0, max_dd=0.02, trades=50) == -1.0
    assert fitness(pf=2.0, rf=1.0, max_dd=-0.01, trades=50) == -1.0
    assert fitness(pf=2.0, rf=1.0, max_dd=math.nan, trades=50) == -1.0


def test_governed_constants_are_pinned():
    assert MIN_TRADES == 20
    assert EPSILON_DD == 0.001
    assert MAX_DD_CAP == 0.045
