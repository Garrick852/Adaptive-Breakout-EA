# AdaptiveBO — MI Path Map & MI-001 Contract Spec

Canonical mapping between the MI plan paths and the real `Adaptive-Breakout-EA`
repository layout, plus the MI-001 wire-contract specification. This document
exists so any agent (junior or senior) implements MIs against the **real** tree
— the plan was written against `MQL5/Experts/AdaptiveBO/...`, which does not
exist in this repo.

## 1. Path mapping (plan → repo)

| Plan path | Real repo path | Status |
| --- | --- | --- |
| `MQL5/Include/Shared/SBridgePacket.mqh` | `eas/AdaptiveBreakoutAI/src/SBridgePacket.mqh` (packaged to `MQL5/Include/AdaptiveBreakoutEA/SBridgePacket.mqh` by `package_mt5.py`) | **DONE — MI-001 (PR #213)** |
| `MQL5/Experts/AdaptiveBO/AdaptiveBO.mq5` | `eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.mq5` (packaged to `MQL5/Experts/AdaptiveBreakoutEA/`) | Existing EA (v1.04) + MI-001/002 hooks |
| `MQL5/Experts/AdaptiveBO/*.mqh` | `eas/AdaptiveBreakoutAI/src/*.mqh` (flat include dir; `#include "name.mqh"`) | Existing + `SBridgePacket.mqh`, `observation_tap.mqh` |
| AOS controller / governance layer (plan: Python core) | `bridge/` (Python package; `bridge.config`, `bridge.io`, `bridge.models`) | Existing scaffold; AOS contract layer **NEW** |
| AOS-side packet decoder (MI-001 dual-end check) | `bridge/contracts/sbridge_packet.py` | **DONE — MI-001 (PR #213)** |
| AOS-side observation reader (MI-002) | `bridge/io/observation_reader.py` | **DONE — MI-002 (PR #214)** |
| AOS command channel (MI-003) | `eas/AdaptiveBreakoutAI/src/aos_command.mqh` + `bridge/io/command_writer.py`, `bridge/io/status_reader.py` | **DONE — MI-003** |
| `ea_runtime.cfg` (terminal sandbox) | `Files/ea_runtime.cfg` → deployed to `MQL5/Files/` | Existing |

> Note: `docs/ARCHITECTURE.md` predates the `bridge/` package and does not list
> it; MI-003+ should update ARCHITECTURE.md when the AOS data flow lands.

## 2. Non-negotiable invariants (unchanged by every MI)

- `SBridgePacket` is **exactly 104 bytes** — never add/remove/reorder fields.
- `AuraArc_Governance.mqh` logic remains unchanged (when it is introduced, it is
  read-only; the EA may only *consult* it, never edit it).
- `status=HOLD` and `go_no_go=UNSET` by default.
- Any stale / missing / invalid observation ⇒ **HOLD** (never a trade).
- `cmd_type` precedence is preserved: `BLOCK/EXIT > HOLD > BUY/SELL`.

## 3. MI-001 spec — 104-byte `SBridgePacket`

Contract-safe design decisions (fold in Copilot review):

1. **pack(1) equivalent** — MQL5 has no `#pragma pack`; the struct uses
   **only `uchar` fields**, so natural alignment is 1 and `sizeof == 104` is
   arithmetic, not luck. The Python side re-validates the same layout table.
2. **Version + CRC** — `version` (byte 2) and `crc16` (bytes 102–103,
   CRC-16/MODBUS over bytes 0..101) prevent silent mis-parses when fields
   evolve; a changed layout bumps `version` and both ends reject mismatches.
3. **Dual-end static checks** — EA `OnInit()` prints
   `Packet Size: 104 (contract 104 bytes)` and returns `INIT_FAILED` (HOLD-safe)
   on any layout mismatch; the AOS decoder validates length + field offsets at
   startup (`bridge/contracts/sbridge_packet.py`).

### Layout (little-endian numerics)

| Offset | Size | Field | Notes |
| --- | --- | --- | --- |
| 0 | 2 | `magic` | `0x53 0x52` (`"SR"`) |
| 2 | 1 | `version` | `1` |
| 3 | 1 | `cmd_type` | 0=HOLD, 1=BUY, 2=SELL, 3=BLOCK/EXIT |
| 4 | 1 | `status` | 0=OK, 1=STALE, 2=ERROR, 3=LOCKED |
| 5 | 1 | `flags` | bit0 `override_valid`, bit1 `risk_veto` |
| 6 | 2 | `reserved1` | zero |
| 8 | 4 | `seq_id` | uint32 |
| 12 | 4 | `ts_sec` | uint32, UTC epoch seconds |
| 16 | 20 | `symbol` | fixed 20-char, null-padded |
| 36 | 4 | `lot` | float32 |
| 40 | 4 | `price_ref` | float32 |
| 44 | 56 | `reserved2` | zero |
| 100 | 2 | `reserved3` | zero |
| 102 | 2 | `crc16` | CRC-16/MODBUS over bytes 0..101 |

Total: **104 bytes** (2+1+1+1+1+2+4+4+20+4+4+56+2+2).

## 4. Copilot corrections baked into later MIs (reference for the implementer)

- **MI-002** — do NOT write a new file per tick. Single file
  (`features_<symbol>.csv` is the existing convention; extend to
  `observations_<symbol>.csv` if needed), **atomic replace** (write `*.tmp`,
  `FileRename` over the target), and carry `ts_ms` + `seq_id` in the payload.
  Write failure ⇒ HOLD, never a fatal exception. — **IMPLEMENTED in MI-002
  (see §6).**
- **MI-003** — conflict priority `BLOCK/EXIT > HOLD > BUY/SELL`; `cmd_type`
  overrides any legacy command; the **local risk gate keeps final veto**
  (even AOS+policy agreement can be rejected by local risk). — **IMPLEMENTED
  in MI-003 (see §7).**
- **MI-004** — unified HWM drawdown `dd = (HWM - Equity) / HWM`, HWM reset
  policy defined in governance config; the 4.5 % cap is **locked in governance
  config**, not scattered hard-codes.
- **MI-005** — fitness `(PF * RF) / max(MaxDD, epsilon)` with a **min-trades
  gate** (trades < N ⇒淘汰) to avoid overfit pseudo-optima.

## 6. MI-002 spec — 6-feature observation tap (DONE)

- **File (FILE_COMMON root, `Common\Files`):** `adaptivebo_observations_<SYMBOL>.csv`,
  header + exactly ONE data line (latest observation), replaced atomically:
  write `*.csv.tmp` then `FileMove(..., FILE_REWRITE)`. No per-tick files.
- **Columns (training-contract order):** `ts_ms, seq_id, symbol, timeframe,
  regime_bias, adx_norm, ema_crossover, range_width_frac, range_position,
  drawdown_fraction`.
- **Feature formulas** (canonical EA-side formulas — the retired AuraArc_Native
  formulas are not in any repo, so these are documented here as authoritative):
  - `regime_bias` — `Drift::Advise()` ∈ {-1, 0, +1} (strategy regime).
  - `adx_norm` — `iADX(14)` MAIN / 100, clamped [0, 1].
  - `ema_crossover` — `(ema12 − ema26) / ATR`, clamped [−1, 1] (closed bar).
  - `range_width_frac` — `(boxHigh − boxLow) / ATR` (Donchian 24, closed bars).
  - `range_position` — `(close − boxLow) / (boxHigh − boxLow)`, clamped [0, 1].
  - `drawdown_fraction` — `(dayHwm − equity) / dayHwm`, day-reset HWM.
- **HOLD gating (non-negotiable):** write failure ⇒ invalid; `ts_ms` older than
  `InpTapStaleMs` (default 2500) ⇒ stale ⇒ invalid; any invalid observation ⇒
  EA OnTick returns before any trade evaluation. `InpTapEnabled=false` disables
  gating (backward compatible). Phase-1 posture: `InpEnableTrading=false`
  (EA stays HOLD; observability continues).
- **AOS side:** `bridge/io/observation_reader.py` — parses the tap, validates
  the header/column contract, `is_stale()` ⇒ HOLD. Tests in
  `python/tests/test_observation_reader.py`.

## 7. MI-003 spec — AOS command channel + telemetry routing (DONE)

- **Files (FILE_COMMON root, `Common\Files`):** `adaptivebo_command_<SYMBOL>.bin`
  (AOS→EA, 104-byte SBridgePacket) and `adaptivebo_status_<SYMBOL>.bin`
  (EA→AOS, 104-byte SBridgePacket). Both read/written with full validation
  (magic/version/CRC) and atomic replace.
- **Staleness clock (both directions):** the PAYLOAD `ts_sec` (UTC epoch
  seconds) — never the file mtime. Same rule as the observation tap's `ts_ms`.
  Default AOS-command stale window 2 s (plan: "disconnect > 2 s ⇒ HOLD").
- **Conflict priority (EA-side, non-negotiable):**
  `BLOCK > HOLD > BUY/SELL`. BLOCK / UNKNOWN / STALE ⇒ HOLD (no trade
  evaluation); HOLD ⇒ no trade; BUY/SELL ⇒ gate ONLY that direction — the
  local strategy intent must MATCH (conflict ⇒ HOLD) and every local risk gate
  keeps FINAL VETO (session/prop/portfolio/cooldown/position).
- **Telemetry routing:** the EA writes its decision (HOLD/BUY/SELL + status
  OK/STALE/ERROR + risk_veto flag) to the status packet (throttled 1 Hz, or
  immediately on state change). No EA→internet HTTP path exists or is added —
  all telemetry flows through the file channel to AOS (Promtail never dials
  the EA).
- **AOS side:** `bridge/io/command_writer.py` (atomic command writes),
  `bridge/io/status_reader.py` (decode + payload-clock staleness). Tests:
  `python/tests/test_aos_channel.py`.
- **Simulation (acceptance):** `InpAosSimCmd` input (OFF/HOLD/BUY/SELL/BLOCK)
  lets the operator trigger a simulated AOS signal without a controller; the
  EA logs the resulting decision and writes the status packet for the AOS
  console to observe.
- **MI-001 byte-order fix (landed with MI-003):** `seq_id`/`ts_sec` in the
  MQL5 packet writer were big-endian vs the documented little-endian contract;
  fixed to LE so the two ends agree (required for any real cross-end traffic).

## 5. Rollback

Every MI commit is additive/reversible:

- MI-001: delete `SBridgePacket.mqh`, `bridge/contracts/sbridge_packet.py`,
  `python/tests/test_sbridge_packet.py`, and remove the EA `OnInit` hook block
  — the EA returns to v1.04 behavior with zero contract code. No risk defaults
  or trade paths are touched by MI-001.
