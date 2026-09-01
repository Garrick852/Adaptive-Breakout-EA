"""Single explicit AOS-side priority resolver (MI-003) + MI-004 hard-cap decision.

Priority (non-negotiable, mirrors the EA's ``AosCommand::PriorityGate``):

    BLOCK > HOLD > BUY/SELL

- any BLOCK  => BLOCK (hard lockdown; nothing else matters)
- else any HOLD / UNKNOWN / missing => HOLD
- else all sources must agree on BUY or SELL, otherwise HOLD (conflict)

MI-004 integration: the AOS controller feeds :func:`hard_cap_decision` the
EA's ``drawdown_fraction`` (same payload the observation reader returns) and
injects the result as one more source into :func:`resolve` — so the
governance-locked 4.5% cap is just another priority input, resolved in the
same single place.

WIRE-VALUE PARITY: ``HARD_DD_CAP`` must equal the EA's
``ESCALATION_MAX_DD_FRACTION`` in ``eas/AdaptiveBreakoutAI/src/escalation.mqh``
(0.045). The cap is governance-locked on BOTH sides; changing it requires a
governed approval (docs/ADAPTIVEBO_MI_MAP.md §8).
"""
from __future__ import annotations

from bridge.contracts.sbridge_packet import CmdType

HARD_DD_CAP = 0.045  # must match escalation.mqh ESCALATION_MAX_DD_FRACTION
RELEASE_DD = 0.040   # hysteresis: lock releases below this (EA-side policy)


def is_tradeable(cmd: int) -> bool:
    """True only for BUY/SELL; HOLD/BLOCK/unknown are never tradeable."""
    return cmd in (CmdType.BUY, CmdType.SELL)


def resolve(*cmds: int) -> int:
    """Aggregate multiple command sources with BLOCK > HOLD > BUY/SELL.

    - ``None`` = source absent (not wired) => ignored, NOT a constraint.
    - An unknown/corrupt VALUE (anything outside 0..3) => HOLD (fail-closed).
    - No sources at all => HOLD (no command => no trade).
    """
    seen = set()
    for c in cmds:
        if c is None:
            continue  # absent source: no constraint
        if int(c) not in (int(CmdType.HOLD), int(CmdType.BUY),
                          int(CmdType.SELL), int(CmdType.BLOCK)):
            return int(CmdType.HOLD)  # unknown/corrupt source => HOLD
        seen.add(int(c))
    if not seen:
        return int(CmdType.HOLD)  # no commands at all => HOLD
    if int(CmdType.BLOCK) in seen:
        return int(CmdType.BLOCK)
    if int(CmdType.HOLD) in seen:
        return int(CmdType.HOLD)
    if len(seen) == 1 and seen <= {int(CmdType.BUY), int(CmdType.SELL)}:
        return seen.pop()
    return int(CmdType.HOLD)  # BUY vs SELL conflict => HOLD


def hard_cap_decision(dd_fraction: float, locked: bool = False) -> int:
    """MI-004: BLOCK when the HWM drawdown breaches the governance cap (or is latched).

    Returns None when clear — the cap injects NO constraint, so an AOS BUY/SELL
    passes through untouched (resolve() ignores None sources).
    """
    if locked or dd_fraction >= HARD_DD_CAP:
        return int(CmdType.BLOCK)
    return None
