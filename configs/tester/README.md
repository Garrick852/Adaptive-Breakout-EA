# Strategy Tester Pass 1

A clean native-mode backtest of `AdaptiveBreakoutAI` on the two symbol/timeframe
configs this repository ships presets for. The purpose is to produce honest,
reproducible out-of-sample evidence for Gate-1 (the EA currently has "no OOS
evidence yet").

## Pass definition

| | EURUSD H1 | XAUUSD H1 |
| --- | --- | --- |
| Preset file | `pass1_eurusd_h1.set` | `pass1_xauusd_h1.set` |
| Strategy | BREAKOUT (forced) | MEANREVERT (forced) |
| Execution | `InpAosCmdEnabled=false` (native) | `InpAosCmdEnabled=false` (native) |
| Armed | `InpEnableTrading=true` | `InpEnableTrading=true` |
| Source preset | `configs/presets/eurusd_h1_breakout.json` | `configs/presets/xauusd_h1_meanrevert.json` |

Both `.set` files are **native + armed**: the EA evaluates its own local strategy
and may open orders, with no AOS command channel and no simulated publisher input.
See `docs/NATIVE_MODE.md` for the mode semantics.

## Why `.set` files (not the JSON presets)

`AdaptiveBreakoutAI.mq5` does not read the `configs/presets/*.json` files — it is
driven entirely by its MQL5 `input` parameters. The `.set` files translate the JSON
presets into those input names so the Strategy Tester actually applies them.

## Mapping (JSON preset key → MQL5 input)

EURUSD H1 (`pass1_eurusd_h1.set`):

| JSON key | MQL5 input | Value |
| --- | --- | --- |
| — (Pass-1 requirement) | `InpAosCmdEnabled` | `false` |
| — (Pass-1 requirement) | `InpEnableTrading` | `true` |
| `router.strategy_mode` | `InpStrategyMode` | `0` (BREAKOUT) |
| `session.use_session_filter` | `InpUseSessionFilter` | `true` |
| `session.session_start_hour` | `InpSessionStartHour` | `7` |
| `session.session_end_hour` | `InpSessionEndHour` | `20` |
| `box.mode` | `InpBoxMode` | `0` (DONCHIAN) |
| `box.lookback_bars` | `InpBreakoutLookback` | `40` |
| `breakout.buffer_points` | `InpBreakoutBufferPts` | `25.0` |
| `risk.use_pending_orders` | `InpBreakoutUsePending` | `true` |
| `breakout.require_close_beyond` | `InpBreakoutRequiresClose` | `true` |
| `risk.atr_mult_sl` | `InpAtrMultSL` | `2.2` |
| `risk.atr_mult_tp` | `InpAtrMultTP` | `4.4` |
| `risk.risk_percent_per_trade` | `InpRiskPercentPerTrade` | `0.5` |
| `drift.breakout_ratio` | `InpDriftBreakoutRatio` | `1.8` |
| `drift.mean_revert_ratio` | `InpDriftMeanRevRatio` | `0.7` |

XAUUSD H1 (`pass1_xauusd_h1.set`):

| JSON key | MQL5 input | Value |
| --- | --- | --- |
| — (Pass-1 requirement) | `InpAosCmdEnabled` | `false` |
| — (Pass-1 requirement) | `InpEnableTrading` | `true` |
| `router.strategy_mode` | `InpStrategyMode` | `1` (MEANREVERT) |
| `session.use_session_filter` | `InpUseSessionFilter` | `true` |
| `session.session_start_hour` | `InpSessionStartHour` | `7` |
| `session.session_end_hour` | `InpSessionEndHour` | `21` |
| `mean_revert.ema_period` | `InpMR_EMAPeriod` | `80` |
| `mean_revert.zscore_threshold` | `InpMR_ZScoreThresh` | `1.8` |
| `risk.atr_mult_sl` | `InpAtrMultSL` | `2.5` |
| `risk.atr_mult_tp` | `InpAtrMultTP` | `5.0` |
| `risk.risk_percent_per_trade` | `InpRiskPercentPerTrade` | `0.4` |
| `drift.breakout_ratio` | `InpDriftBreakoutRatio` | `2.2` |
| `drift.mean_revert_ratio` | `InpDriftMeanRevRatio` | `0.9` |

## Deliberately left at EA defaults (confirm before running)

- **Prop rules OFF** (`InpEnablePropRules=false`): Pass 1 is a *raw signal* pass. The
  prop-rule rail (daily-loss / total-DD / cooldown) can be layered on in a later pass.
- **`InpMinAtrFilterPts`** left at `10.0`: the JSON `min_atr_filter` is expressed in
  *price* (`0.0005` / `0.5`) while the MQL5 input is in *points*; the conversion was
  intentionally not auto-applied. Set it explicitly if the ATR floor should differ.
- **`InpAtrTimeframe=PERIOD_CURRENT`**: ATR uses the chart timeframe (H1), as intended.
- **Portfolio risk guard** (`InpMaxGlobalRiskPct=10`, `InpGlobalStopOutPct=15`) and
  **escalation rail (4.5%)** remain at governed defaults and are *not* tunable inputs.

## Tester-global settings (not in the `.set`; set in the tester, confirm before running)

| Setting | Recommended | Notes |
| --- | --- | --- |
| Symbol | EURUSD / XAUUSD | one run each |
| Period | H1 | |
| Modeling | Every tick based on real ticks (`Model=4`) | fall back to "1 minute OHLC" (`Model=1`) if real-tick history is sparse |
| Spread | current | or fixed if the broker data is noisy |
| Date range | 2024.01.01 – 2026.01.01 | adjust; keep the window identical across both symbols |
| Deposit | 100000 USD | $100k avoids 0.01-lot rounding distortion at 0.4% risk on XAUUSD (2.5× ATR stop) |
| Leverage | 1:100 | |

## Run it

GUI: `View → Strategy Tester` → pick the symbol/period/modeling above → select
`AdaptiveBreakoutAI` → **Inputs → Load** the matching `.set` file → Start.

Headless — the two generated templates `pass1_eurusd_h1.ini` and `pass1_xauusd_h1.ini`
already carry these settings and the `.set` inputs, targeting a **non-live** terminal
(never `9D31656F`, which is running SRC live):

```text
terminal64.exe /config:"<repo>\configs\tester\pass1_eurusd_h1.ini"
terminal64.exe /config:"<repo>\configs\tester\pass1_xauusd_h1.ini"
```

## Reading the result

`OnTester()` returns the WFO fitness `(ProfitFactor * RecoveryFactor) /
max(MaxDD, 0.001)` and **fail-closes to -1.0** when: fewer than 20 trades, invalid
PF/RF, or day-reset HWM drawdown ≥ 4.5%. A Pass-1 result of `-1.0` means "not enough
clean evidence", not "profitable" — it is the overfit/underevidence gate, by design.
