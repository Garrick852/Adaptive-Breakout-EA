# Configuration Files

## Location

All configs live under `configs/`:

- `ea_default.json`
- `router_demo.json`
- `risk_presets.json`
- `symbols_map.json`
- `session_windows.json` (optional)
- `ea_runtime.cfg` (generated)

Schemas live under `configs/schemas/`:

- `base.schema.json`
- `ea.schema.json`
- `router.schema.json`
- `risk.schema.json`
- `symbols.schema.json`
- `signals.schema.json`

## EA Defaults (`ea_default.json`)

Validated by `ea.schema.json`. Defines:

- ATR parameters
- Box mode & lookback
- Breakout buffer and close behavior
- Risk per trade
- Pending order usage
- ATR trailing behavior

`ea_default.json` is the **source of truth**; `ea_runtime.cfg` is generated from it for the EA.

## Router Config (`router_demo.json`)

Validated by `router.schema.json`. Defines:

- Per-symbol routes: symbol, preferred strategy, priority
- AI and drift enablement
- Fallback strategy and confidence thresholds

Used by dashboards and routing tools; can be wired into the EA in the future.

## Risk Presets (`risk_presets.json`)

Validated by `risk.schema.json`. Defines named risk profiles (e.g.:

- `PROP_CHALLENGE_P1`
- `PROP_CHALLENGE_P2`
- `FUNDING`
- `BROKER`

Each profile can specify default risk percentage, max DD, daily loss limit, etc.

## Symbols Map (`symbols_map.json`)

Validated by `symbols.schema.json`. Defines per-symbol overrides for:

- ATR period, multipliers
- Box settings
- Buffers, timeframes

## Session Windows (`session_windows.json`)

Optional, validated by `session.schema.json` (if present). Defines:

- Allowed / blocked trading windows per symbol or globally
- Blackout windows around specific dates/times

Currently used by tooling; a future EA version can read a derived flat format.

## EA Runtime Config (`ea_runtime.cfg`)

A flat key=value file generated from `ea_default.json`, containing keys like:

```text
atr_period=14
atr_mult_sl=2.0
atr_mult_tp=4.0
min_atr_filter=0.0
box_mode=DONCHIAN
box_lookback_bars=50
time_from_hour=8
time_to_hour=17
breakout_buffer_pts=20
require_close_beyond=true
risk_percent_per_trade=1.0
use_pending_orders=false
use_atr_trail=false
atr_trail_mult=1.5
```

Read by the EA via `ConfigLoader::LoadEAConfig()` at `OnInit()`.
