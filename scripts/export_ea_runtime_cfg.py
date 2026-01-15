import json
import argparse
from pathlib import Path

DEFAULT_SCHEMA_PATH = Path("configs/schema/ea_config.schema.json")


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def export_ea_runtime_cfg(cfg: dict, out_path: Path) -> None:
    """
    Export a flat ea_runtime.cfg file for AdaptiveBreakoutAI.mq5
    from the validated JSON configuration.
    """
    lines = []

    # --- Session ---
    session = cfg.get("session", {})
    lines.append(f"InpUseSessionFilter={1 if session.get('use_session_filter', False) else 0}")
    lines.append(f"InpSessionStartHour={int(session.get('session_start_hour', 0))}")
    lines.append(f"InpSessionEndHour={int(session.get('session_end_hour', 23))}")

    # --- Prop rules ---
    prop = cfg.get("prop_rules", {})
    oper_mode_str = prop.get("oper_mode", "NORMAL").upper()
    oper_mode_map = {
        "NORMAL": 0,
        "AGGRESSIVE": 1,
        "CONSERVATIVE": 2,
    }
    oper_mode_val = oper_mode_map.get(oper_mode_str, 0)
    lines.append(f"InpOperMode={oper_mode_val}")
    lines.append(f"InpDailyLossStopPct={float(prop.get('daily_loss_stop_pct', 5.0))}")
    lines.append(f"InpMaxTotalDDPct={float(prop.get('max_total_dd_pct', 10.0))}")
    lines.append(f"InpMinMinutesBetweenTrades={int(prop.get('min_minutes_between_trades', 5))}")

    # --- Hedging / concurrency ---
    hedging = cfg.get("hedging", {})
    lines.append(f"InpHedgingDisabled={1 if hedging.get('hedging_disabled', True) else 0}")
    lines.append(f"InpMaxConcurrentTrades={int(hedging.get('max_concurrent_trades', 1))}")

    # --- Volatility / ATR ---
    vol = cfg.get("volatility", {})
    lines.append(f"InpATRPeriod={int(vol.get('atr_period', 14))}")
    lines.append(f"InpMinATRFilter={float(vol.get('min_atr_filter', 0.0))}")

    # --- Drift thresholds ---
    drift = cfg.get("drift", {})
    lines.append(f"InpDriftBreakoutRatio={float(drift.get('breakout_ratio', 2.0))}")
    lines.append(f"InpDriftMeanRevRatio={float(drift.get('mean_revert_ratio', 0.8))}")

    # --- Box settings ---
    box = cfg.get("box", {})
    box_mode_str = box.get("mode", "DONCHIAN").upper()
    box_mode_map = {
        "DONCHIAN": 0,
        "TIMERANGE": 1,
    }
    box_mode_val = box_mode_map.get(box_mode_str, 0)
    lines.append(f"InpBoxMode={box_mode_val}")
    lines.append(f"InpBoxLookbackBars={int(box.get('lookback_bars', 50))}")
    lines.append(f"InpTimeFromHour={int(box.get('time_from_hour', 8))}")
    lines.append(f"InpTimeToHour={int(box.get('time_to_hour', 17))}")

    # --- Breakout behaviour ---
    breakout = cfg.get("breakout", {})
    lines.append(f"InpBreakoutBufferPts={float(breakout.get('buffer_points', 20.0))}")
    lines.append(f"InpRequireCloseBeyond={1 if breakout.get('require_close_beyond', True) else 0}")

    # --- Risk / SL-TP ---
    risk = cfg.get("risk", {})
    lines.append(f"InpATRMultSL={float(risk.get('atr_mult_sl', 2.0))}")
    lines.append(f"InpATRMultTP={float(risk.get('atr_mult_tp', 4.0))}")
    lines.append(f"InpRiskPercentPerTrade={float(risk.get('risk_percent_per_trade', 1.0))}")
    lines.append(f"InpUsePendingOrders={1 if risk.get('use_pending_orders', False) else 0}")

    # --- Mean-reversion parameters ---
    mr = cfg.get("mean_revert", {})
    lines.append(f"InpMR_EMAPeriod={int(mr.get('ema_period', 50))}")
    lines.append(f"InpMR_ZScoreThresh={float(mr.get('zscore_threshold', 1.5))}")

    # --- Router / AI ---
    router = cfg.get("router", {})
    mode_str = router.get("strategy_mode", "AUTO").upper()
    mode_map = {
        "BREAKOUT": 0,
        "MEANREVERT": 1,
        "AUTO": 2,
    }
    mode_val = mode_map.get(mode_str, 2)
    lines.append(f"InpStrategyMode={mode_val}")
    lines.append(f"InpAIEnabled={1 if router.get('ai_enabled', True) else 0}")
    lines.append(f"InpAISignalFile={router.get('ai_signal_file', 'ai_signal.txt')}")

    # --- Trailing ---
    trailing = cfg.get("trailing", {})
    lines.append(f"InpUseATRTrail={1 if trailing.get('use_atr_trail', False) else 0}")
    lines.append(f"InpATRTrailMult={float(trailing.get('atr_trail_mult', 1.5))}")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for line in lines:
            f.write(line + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=str, help="JSON config path")
    parser.add_argument(
        "--schema",
        type=str,
        default=str(DEFAULT_SCHEMA_PATH),
        help="JSON Schema path"
    )
    parser.add_argument(
        "--out",
        type=str,
        default="ea_runtime.cfg",
        help="Output ea_runtime.cfg path"
    )
    args = parser.parse_args()

    cfg_path = Path(args.config)
    # schema_path = Path(args.schema)  # kept for future validation

    cfg = load_json(cfg_path)

    # If you have validation utils, call them here with schema_path.
    # e.g. schema = load_schema(schema_path); validate_config(cfg, schema)

    export_ea_runtime_cfg(cfg, Path(args.out))


if __name__ == "__main__":
    main()
