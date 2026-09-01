"""Contract tests for the AOS-side priority resolver (MI-003) + MI-004 hard cap.

Pins the BLOCK > HOLD > BUY/SELL ordering, conflict => HOLD, unknown => HOLD,
and the governance-locked 4.5% boundary — wire-value parity with the EA's
escalation.mqh constants.
"""
from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

from bridge.contracts.aos_priority import (  # noqa: E402
    HARD_DD_CAP,
    hard_cap_decision,
    is_tradeable,
    resolve,
)
from bridge.contracts.sbridge_packet import CmdType  # noqa: E402


def test_priority_block_wins_over_everything():
    assert resolve(CmdType.BLOCK, CmdType.BUY) == CmdType.BLOCK
    assert resolve(CmdType.BLOCK, CmdType.SELL, CmdType.HOLD) == CmdType.BLOCK


def test_priority_hold_blocks_buy_sell():
    assert resolve(CmdType.HOLD, CmdType.BUY) == CmdType.HOLD
    assert resolve(CmdType.SELL, CmdType.HOLD) == CmdType.HOLD


def test_agreement_passes_through():
    assert resolve(CmdType.BUY, CmdType.BUY) == CmdType.BUY
    assert resolve(CmdType.SELL) == CmdType.SELL


def test_conflict_is_hold():
    assert resolve(CmdType.BUY, CmdType.SELL) == CmdType.HOLD


def test_unknown_or_missing_is_hold():
    assert resolve() == CmdType.HOLD                       # no commands at all => HOLD
    assert resolve(None) == CmdType.HOLD                   # all sources absent => HOLD
    assert resolve(99) == CmdType.HOLD                     # corrupt value => HOLD
    assert resolve(CmdType.BUY, 99) == CmdType.HOLD        # corrupt source => HOLD
    assert resolve(CmdType.BUY, None) == CmdType.BUY       # absent source is NOT a veto


def test_is_tradeable_only_buy_sell():
    assert is_tradeable(CmdType.BUY) is True
    assert is_tradeable(CmdType.SELL) is True
    assert is_tradeable(CmdType.HOLD) is False
    assert is_tradeable(CmdType.BLOCK) is False


def test_hard_cap_governance_boundary():
    assert HARD_DD_CAP == 0.045  # parity with escalation.mqh
    assert hard_cap_decision(0.0449) is None              # clear => no constraint
    assert hard_cap_decision(0.0450) == CmdType.BLOCK
    assert hard_cap_decision(0.0500) == CmdType.BLOCK


def test_hard_cap_latched_lock():
    assert hard_cap_decision(0.001, locked=True) == CmdType.BLOCK


def test_hard_cap_boundary_returns_none_when_clear():
    # Clear cap => NO constraint (None), so an AOS BUY passes through resolve().
    assert hard_cap_decision(0.02) is None
    assert resolve(CmdType.BUY, hard_cap_decision(0.02)) == CmdType.BUY


def test_hard_cap_plugs_into_resolver():
    # AOS BUY + cap breach => BLOCK (the cap injects a source into resolve).
    assert resolve(CmdType.BUY, hard_cap_decision(0.051)) == CmdType.BLOCK
    # AOS SELL + latched lock => BLOCK.
    assert resolve(CmdType.SELL, hard_cap_decision(0.01, locked=True)) == CmdType.BLOCK
