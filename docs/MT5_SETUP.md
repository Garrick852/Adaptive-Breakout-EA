# MT5 Setup and Deployment

## 1. Install MetaTrader 5

- Install MetaTrader 5 (desktop) and note:
  - The path to `metaeditor64.exe`
  - The Data Folder path from MT5 (`File -> Open Data Folder`)

## 2. Configure `ci_mt5_build.py`

Edit `scripts/ci_mt5_build.py`:

- Set `METAEDITOR_EXE` to the correct path, e.g.:

```python
METAEDITOR_EXE = r"C:\Program Files\MetaTrader 5\metaeditor64.exe"
```

## 3. Build the EA

From the repo root:

```bash
python scripts/ci_mt5_build.py
```

This compiles `eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.mq5`. The `.ex5` is written into your MT5 Data Folder under `MQL5\Experts\`.

## 4. Package for Deployment

```bash
python scripts/export_ea_runtime_cfg.py
python scripts/package_mt5.py
```

This generates:

```text
dist/mt5_package/
└── MQL5/
    ├── Experts/AdaptiveBreakoutAI/AdaptiveBreakoutAI.mq5 + .mqh
    └── Files/ea_runtime.cfg
```

## 5. Deploy to a Terminal

Edit `deploy_mt5.bat`:

```bat
set MT5_DATA=C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\<hash>\MQL5
set DIST=dist\mt5_package\MQL5
```

Then run:

```bat
deploy_mt5.bat
```

This copies:

- `Experts/AdaptiveBreakoutAI/*` into `%MT5_DATA%\Experts\AdaptiveBreakoutAI\`
- `Files/ea_runtime.cfg` into `%MT5_DATA%\Files\`

## 6. Attach EA in MT5

1. Restart MT5 (or refresh the Navigator).
2. In the Navigator -> Experts:
   - Find `AdaptiveBreakoutAI`.
3. Drag it onto the chart:
   - Verify inputs match expectations.
   - Ensure Algo Trading is enabled.
