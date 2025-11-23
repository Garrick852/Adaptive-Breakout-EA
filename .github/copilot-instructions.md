# Adaptive Breakout EA - Copilot Instructions

## Architecture Overview

This is a **diagnostics-first** trading system combining:
- **MQL5 EA** (`eas/AdaptiveBreakoutAI/src/`): Expert Advisor for MetaTrader 5 with regime detection, sensitivity scoring, and drift monitoring
- **Python tooling** (`python/`): Config validation, testing, and glyph rendering
- **JSON Schemas** (`configs/schema/`): Config validation (currently mostly empty placeholders)
- **Glyph-based diagnostics**: EA emits structured log messages (`Glyph: <type> = <value>`) for CI validation

### Key Components
- `AdaptiveBreakoutAI.mq5`: Main EA with breakout logic, regime detection, sensitivity scoring, risk caps
- `drift_detection.mqh`: Monitors model performance degradation by analyzing trade history
- `render_matrix.py`: Generates demo glyph files for golden comparison testing
- Config schemas: Define structure for `symbols`, `risk`, `mode`, `name` fields

## Critical Workflows

### Development Setup
```bash
make setup  # Install deps + pre-commit hooks
make lint   # Ruff + mypy on python/ and dashboards/
make test   # pytest in python/tests/
make glyphs # Render glyphs and compare to golden files
```

**Pre-commit hooks** (`.pre-commit-config.yaml`):
- Ruff linting and formatting with auto-fix
- MyPy type checking with PyYAML types
- YAML validation, EOF fixer, trailing whitespace removal
- Private key detection for security

**Note**: `make render` references `configs/demo/router_demo.yaml` which doesn't exist yet. Use `ea_adaptive_breakout_demo.yaml` as the template for creating new demo configs.

### Testing Philosophy
- **Golden file testing**: `test_glyphs.py` compares rendered output against `dashboards/glyphs/expected/`
- **Schema validation**: `test_schema.py` validates YAML configs have required fields (`name`, `symbols`, `risk`, `mode`) with correct types
- **Deterministic rendering**: `render_matrix.py` uses `seeds.python` from config for reproducibility

### CI Pipeline (`.github/workflows/ea-backtest.yml`)
- Matrix builds on Python 3.8, 3.9, 3.10
- Runs ruff, mypy, pytest with coverage
- Validates config schemas
- Compares glyph rendering vs golden files
- Fails if glyphs don't match expected output

### Manual MT5 Backtesting
The EA must be tested manually in MetaTrader 5:
1. Open MT5 and load `eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.mq5`
2. Compile in MetaEditor (F7) - check for errors
3. Attach to chart, configure inputs, enable Algo Trading
4. Run Strategy Tester for backtests with historical data
5. Check Experts tab for glyph output: `Glyph: <Type> = <Value>`
6. Include backtest results in PR (see `.github/PULL_REQUEST_TEMPLATE.md`)

## Project-Specific Conventions

### MQL5 Code Style
- Use `EmitGlyph()` helper for diagnostics: `EmitGlyph("MetricName", value)` or `EmitGlyph("EventType", "description")`
- Always emit glyphs for: regime detection, sensitivity scores, drift alerts, risk cap breaches, trade placements
- Input validation in `ValidateInputs()` at `OnInit()`
- Global state variables prefixed descriptively (e.g., `sensitivityScore`, `currentRegime`, `lastTradeTime`)
- Magic number standardized: `123456` used across EA and drift detection module
- Technical indicators: Use MQL5 built-ins like `iATR()`, `iClose()`, `iHigh()`, `iBars()` for market data

### Python Code Standards
- **Linting**: Ruff with 100-char line length, targets Python 3.11, selects E/F/I/B/UP rules
- **Type checking**: mypy with `--ignore-missing-imports`
- **Testing**: pytest in `python/tests/`, use parametrize for multiple configs
- **Imports**: Ruff enforces isort-style import ordering

### Configuration Management
- Demo configs in `configs/demo/*.yaml`
- Required fields (enforced by `test_schema.py`): `name` (str), `symbols` (list), `risk` (dict), `mode` (str)
- Render configs need `seeds.python` for deterministic output
- Run `python python/tools/validate_configs.py` (note: currently basic JSON validator, not YAML-aware)

### Glyph System
Glyphs are structured diagnostic outputs from the EA:
- Format: `Glyph: <Type> = <Value>` or `Glyph: <Type> - <Note>`
- Critical glyphs: `DriftDetected`, `Regime`, `SensitivityScore`, `BreakoutUp`, `TradePlaced`
- Golden files in `dashboards/glyphs/expected/` must match render output exactly
- Update goldens only when intentional behavior changes (document rationale in PR)

## Integration Points

### MQL5 ↔ Python
- No direct runtime integration
- Python tools validate configs that control EA parameters
- Glyphs emitted by EA can be captured in logs for post-trade analysis (not yet implemented)

### Config Schema Flow
1. Define structure in YAML configs (`configs/demo/`)
2. Schemas in `configs/schema/` (currently empty - opportunity for improvement)
3. Python tests (`test_schema.py`) validate required fields and types
4. EA reads parameters via input variables (not from YAML at runtime)

### Drift Detection Pattern
- `drift_detection.mqh` module is **integrated** into the main EA (v0.3.0+)
- `MonitorDrift()` called in `OnTick()` to analyze recent trade history
- Analyzes trade history via `HistoryDealsTotal()` and `HistoryDealGetTicket()`
- Filters by magic number (`InpDriftMagicNumber = 123456`)
- Calculates win rate over last N trades where sensitivity was high
- Sets `isModelDrifting = true` and emits `DriftDetected` glyph when performance drops below threshold
- EA checks `IsModelDrifting()` before trading and emits `TradingHalted` glyph to halt trades

## Key File References

- `Makefile`: Primary entry point for all dev commands
- `ruff.toml`: Linter config (targets `python/` and `dashboards/`)
- `pytest.ini`: Test discovery in `python/tests/`
- `requirements.txt`: Python 3.11+ with jsonschema, pytest, ruff, mypy, pyyaml
- `CONTRIBUTING.md`: PR guidelines emphasizing diagnostic artifacts and small focused changes
- `ROADMAP.md`: Planned features (adaptive volatility filters, multi-symbol routing, advanced dashboards)

## Common Pitfalls

1. **Glyph format changes break CI**: Always update golden files when modifying glyph output
2. **Schema validation is minimal**: `configs/schema/*.json` are mostly empty - tests rely on Python-side validation
3. **render_matrix.py requires `seeds.python` in config**: Missing seed causes non-deterministic output
4. **MQL5 EA uses fixed lot sizing**: No dynamic position sizing based on config risk parameters yet
5. **validate_configs.py is JSON-only**: Doesn't validate YAML configs despite the name - use `test_schema.py` instead
6. **router_demo.yaml missing**: Makefile references it but file doesn't exist - use `ea_adaptive_breakout_demo.yaml` as template

## When Making Changes

- **Adding EA inputs**: Update `ValidateInputs()`, emit relevant glyphs, add test case
- **Modifying glyphs**: Update `dashboards/glyphs/expected/` golden files and document why in PR
- **New config fields**: Add to `test_schema.py` required fields, update `ea_adaptive_breakout_demo.yaml`
- **Python tooling**: Ensure ruff/mypy pass, add pytest coverage, follow existing patterns in `python/tests/`
- **Schemas**: Currently placeholders - populating these is tracked in roadmap for proper JSONSchema validation
