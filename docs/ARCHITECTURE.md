# Adaptive Breakout EA – Architecture

## Overview

The project consists of:

- A MetaTrader 5 Expert Advisor (`AdaptiveBreakoutAI.mq5`) with:
  - Breakout and mean-reversion strategies
  - Prop-firm-friendly risk controls
  - AI signal + drift fusion router
  - Optional ATR-based trailing stops

- A configuration layer:
  - JSON configs under `configs/` validated by JSON Schema Draft-07
  - A flat `ea_runtime.cfg` file read by the EA at runtime

- Tooling and CI:
  - `scripts/validate_ea_config.py`
  - `scripts/export_ea_runtime_cfg.py`
  - `scripts/ci_mt5_build.py`
  - `scripts/package_mt5.py`

- Dashboards:
  - `/dashboards/backend` FastAPI service exposing configs and metrics
  - `/dashboards/frontend` scaffold for a web UI

## Data Flow

1. **Config design & validation**

   - Edit JSON configs in `configs/`.
   - Validate them against schemas in `configs/schemas/` using `validate_ea_config.py`.
   - Export `ea_runtime.cfg` from `ea_default.json` using `export_ea_runtime_cfg.py`.

2. **Build & packaging**

   - Compile EA using MetaEditor via `ci_mt5_build.py`.
   - Package `.mq5` + `.mqh` and `ea_runtime.cfg` into `dist/mt5_package/MQL5/` using `package_mt5.py`.

3. **Deployment**

   - Use `deploy_mt5.bat` to copy:
     - `Experts/AdaptiveBreakoutAI/*` into the terminal's `MQL5/Experts/AdaptiveBreakoutAI/`
     - `Files/ea_runtime.cfg` into the terminal's `MQL5/Files/`

4. **Runtime (MT5)**

   - EA loads `ea_runtime.cfg` at `OnInit()`.
   - On each tick, EA:
     - Applies session and prop rules
     - Uses ATR and box structure
     - Fuses AI signals with drift detection
     - Executes breakout or mean-revert trades
     - Optionally applies ATR trailing

5. **Dashboards**

   - Backend reads the same configs and schemas to present:
     - Effective EA config
     - Router configuration
     - (Later) live or backtest metrics
