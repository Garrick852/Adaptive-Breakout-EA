"""MI-005 WFO fitness contract (mirror of the EA's OnTester).

Formula (must match ``AdaptiveBreakoutAI.mq5`` OnTester):

    fitness = (ProfitFactor * RecoveryFactor) / max(MaxDD, EPSILON_DD)

with:

- ``MaxDD`` = peak DAY-RESET HWM drawdown fraction (the SAME metric and reset
  policy as the live MI-004 escalation rail — never the whole-run peak-to-trough
  percent, so optimizer scoring can't drift from live gating).
- reject (``-1.0``) when: trades < min_trades, PF/RF invalid (NaN/<=0),
  MaxDD >= max_dd_cap (0.045, parity with escalation.mqh), or any stat invalid
  (fail-closed).
- the gates are GOVERNED constants (min_trades, epsilon, cap), not tunable
  inputs — the optimizer must not be able to tune them away.

WIRE-VALUE PARITY: max_dd_cap must equal ``ESCALATION_MAX_DD_FRACTION``
(0.045); min_trades must equal the EA's ``MIN_TRADES`` (20); epsilon must equal
``EPSILON_DD`` (0.001).
"""
from __future__ import annotations

import math

MIN_TRADES = 20
EPSILON_DD = 0.001
MAX_DD_CAP = 0.045  # parity with escalation.mqh ESCALATION_MAX_DD_FRACTION


def fitness(
    pf: float,
    rf: float,
    max_dd: float,
    trades: int,
    min_trades: int = MIN_TRADES,
    epsilon: float = EPSILON_DD,
    max_dd_cap: float = MAX_DD_CAP,
) -> float:
    """Return the genetic fitness, or -1.0 when the run must be rejected.

    Fail-closed: any invalid/negative/NaN input or a breached gate => -1.0,
    never a large positive score.
    """
    for value in (pf, rf, max_dd, float(trades)):
        if not isinstance(value, (int, float)) or not math.isfinite(value):
            return -1.0
    if trades < min_trades:
        return -1.0
    if pf <= 0.0 or rf <= 0.0:
        return -1.0
    if max_dd < 0.0 or max_dd >= max_dd_cap:
        return -1.0
    denominator = max(max_dd, epsilon)
    if denominator <= 0.0:
        return -1.0
    return (pf * rf) / denominator
