# AdaptiveBO Pilot Run Checklist — Phase 4 (single-symbol demo)

Operator-side checklist for the first live/demo pilot of the MI-series EA
(MI-001 … MI-005, PRs #213–#217). **Scope:** 1 symbol · 0.01 lots · 72 h soak ·
Telegram/HITL · escalation + HOLD validation on a demo account.

References: `docs/MT5_SETUP.md`, `docs/MQL5_DEPLOYMENT.md`,
`docs/ADAPTIVEBO_MI_MAP.md` (MI specs §3, §6–§9).

---

## 0. Preconditions

- [ ] All 5 MI PRs merged in order (#213 → #214 → #215 → #216 → #217); working tree clean at HEAD.
- [ ] MetaEditor headless compile: **0 errors** (evidence: latest compile log).
- [ ] Demo account (not prop); single symbol chosen (e.g. `EURUSD` H1, per `configs/presets/eurusd_h1_*.json`).
- [ ] Terminal + MetaEditor on the trading machine; `MT5_DATA_DIR` known.

## 1. Deploy

- [ ] `python scripts/package_mt5.py` (or `make package`) → `dist/Adaptive-Breakout-EA-*.zip`.
- [ ] `deploy_mt5.bat` → `MQL5/Experts/AdaptiveBreakoutEA/` + `MQL5/Files/ea_runtime.cfg`.
- [ ] **String/marker check:** verify the deployed `.mq5/.mqh` contain the expected markers (e.g. the `OnTester` function and the `escalation.mqh` include line) — the same marker-discipline used by the cosmic `sync_src_to_terminals` script, so a stale copy can never pass silently.
- [ ] Login demo account; add symbol to Market Watch; attach EA to the symbol chart.

## 2. Pilot configuration (only ONE change from defaults)

| Input | Value | Note |
| --- | --- | --- |
| `InpEnableTrading` | **true** | the only non-default; Phase-4 unlock |
| `InpTapEnabled` / `InpTapIntervalMs` / `InpTapStaleMs` | true / 1000 / 2500 | defaults (MI-002) |
| `InpAosCmdEnabled` / `InpAosCmdStaleSec` / `InpAosSimCmd` | true / 2 / `AOS_SIM_OFF` | real file channel (MI-003) |
| lot sizing | 0.01 (TradeExec placeholder) | matches pilot; see §Flags |

## 3. Pre-flight validation (T-0)

- [ ] Experts log shows `Packet Size: 104 (contract 104 bytes)` + `EA Initialized Successfully` (MI-001).
- [ ] `Common\Files\adaptivebo_observations_<SYMBOL>.csv` appears, refreshes ~1/s, header/columns match the contract, `ts_ms` fresh (MI-002).
- [ ] **Fail-closed HOLD:** with no command file, expect `AOS-CMD: command -1 not tradeable -> HOLD` every ~5 s (MI-003 UNKNOWN ⇒ HOLD). Then publish a command (`python -m bridge.io.command_writer --symbol ... --cmd 1 --out <Common\Files>`) → observe the BUY gate; publish `--cmd 0` → HOLD; `--cmd 3` → BLOCK (MI-003 priority).
- [ ] **Stale drill:** stop the publisher → within ~2 s the EA returns to HOLD (payload-clock staleness, not file mtime).
- [ ] **Escalation drill:** open a large losing manual position (e.g. 1.0 lot) so the day-HWM drawdown reaches 4.5 % → expect `ESCALATION: drawdown 0.0450 ... CloseAll + BLOCK/EXIT`, all positions closed, status packet `BLOCK/LOCKED`, EA refuses new trades; recovery below 4.0 % → `UNLOCKED` (MI-004).
- [ ] Status heartbeat: `Common\Files\adaptivebo_status_<SYMBOL>.bin` decodes cleanly (magic/version/CRC) and its payload `ts_sec` stays fresh.

## 4. HITL mode — SELECTED: Option 1 (production-like confidence)

- [x] **Option 1 (selected):** the notifier bridge (`bridge/monitor/status_notifier.py`) watches `adaptivebo_status_*.bin` → Telegram alerts on decision changes and escalation trips (state-change driven, read-only, fail-closed sender).
- [ ] Notifier deployed on the trading machine:
      `set TELEGRAM_BOT_TOKEN=...` and `set TELEGRAM_CHAT_ID=...`
      `python -m bridge.monitor.status_notifier --symbol <SYMBOL> --watch`
      (add `--out <Common\Files>` when `OBSERVATIONS_DIR` is not set; run `--dry-run` first)
- [ ] Notifier smoke test: publish `--cmd 3` via `command_writer` → expect the ESCALATION/LOCKDOWN Telegram alert (or the dry-run line).
- [ ] HITL checkpoints armed at **T-0 / 24 h / 48 h / 72 h** (Option-1 alerts + checkpoint sign-offs).

## 5. Soak (0–72 h)

- [ ] Observation tap continuous (no write failures; `ts_ms` always fresh).
- [ ] Status channel responsive; decision states match commands.
- [ ] No trade outside the AOS direction; no HOLD beyond commanded; escalation never trips unintentionally.
- [ ] Alerts flowing on the selected HITL mode.

## 6. Exit criteria (72 h)

- [ ] No governance violation; no unexpected HOLD; escalation rail tripped only in the deliberate drill; observation/status channels healthy; equity within bounds.
- [ ] Post-soak review of `adaptivebo_observations_*.csv` + status history; log any deviations here.

## 7. Rollback

- [ ] Detach EA → delete `adaptivebo_*` files from `Common\Files` → set `InpEnableTrading=false` → (if needed) `git revert` the pilot HEAD. Fail-closed by design: a stopped publisher alone returns the EA to HOLD.

---

## Flags (open items, not part of this checklist's mechanical steps)

1. **Lot sizing** is the TradeExec placeholder (0.01) — correct for the pilot, but `InpRiskPercentPerTrade` is not yet honored; a governance review is required before scaling beyond 0.01 (a real follow-up code slice).
2. **Telegram/HITL wiring** — **resolved: Option 1** (see §4). The notifier bridge (`bridge/monitor/status_notifier.py`) uses the standard Bot API, the same contract as the cosmic `ops/telegram` `AuraArcBot.send_message` (`TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`).
