# Native and AOS-controlled execution

`InpAosCmdEnabled` selects the existing execution policy, independently of
operator arming:

| Input | Default | Meaning |
| --- | --- | --- |
| `InpEnableTrading` | `false` | HOLD: no local strategy evaluation or new order attempts |
| `InpAosCmdEnabled` | `true` | Require a fresh, valid AOS BUY/SELL and restrict the local strategy to that direction |
| `InpAosSimCmd` | `AOS_SIM_OFF` | No simulated publisher command |

For native/standalone evaluation, explicitly select `InpAosCmdEnabled=false`.
The EA does not read the directional publisher file or simulation override in
this mode. Both existing strategies receive `DIR_ANY`: they select their own
BUY or SELL, or no trade. No external signal is manufactured. Missing or stale
publisher input cannot select SELL by accident.

**Selecting native mode does not arm execution.** Keep `InpEnableTrading=false`
for diagnostics. Any later arming is a separate operator decision, first in an
isolated Strategy Tester/demo environment, not authorization to trade live.
Native mode does not create new signals, copy trades, mirror/invert positions,
or add hedging.

## Safety gates and diagnostics

Both modes retain the same escalation rail (first on every tick), observation
validity gate, session filter, prop-rule call, portfolio drawdown guard,
cooldown, existing-position guard, ATR checks and strategy selection.
Disabling command direction gating does not disable these local controls.
An escalation lock still reports BLOCK/LOCKED; all local vetoes still HOLD.
The inherited escalation rail can close positions on a drawdown breach even
while new execution is disabled; this change does not alter that behavior.

Controlled mode still uses the existing 104-byte packet reader: missing,
invalid, future-dated or stale payloads fail closed, as do HOLD and BLOCK.
With the default staleness window, payload age above 2 seconds is rejected.
Fresh valid BUY/SELL only authorizes the matching direction, subject to every
local veto. Existing simulation inputs are acceptance-test overrides, not
the native path; leave them OFF.

The Experts log identifies `mode=native` or `mode=AOS-controlled` and whether
execution is armed. Native order attempts are identified as local strategy
attempts, not received AOS commands. The existing status wire has no native
action field, so native attempts retain HOLD/OK with no override flag rather
than fabricating a publisher BUY/SELL. This status is not a fill receipt.

## Limitations and deployment boundary

This repository's MI integration predates the installed terminal copy and is
not a drop-in replacement for any later, uncommitted telemetry additions.
There is no AOS.TWIN operator-stop/Guardian file consumer in this EA baseline;
native mode must not be described as integrated with that external stop.
The prop-rule implementation remains a placeholder, and trade execution still
uses a fixed placeholder lot size of 0.01 rather than risk-based sizing.
Preserving these interfaces does not make them production-ready safeguards.

This source change does not deploy anything, change terminal/account inputs,
enable Algo Trading, or modify Common Files. Review the complete integrated
baseline and validate strategy/risk behavior in isolation before any separately
authorized deployment.
