# Project Roadmap

This document outlines the key upcoming features for the Adaptive Breakout AI project. Our focus is on enhancing the Expert Advisor (EA) with state-of-the-art trading capabilities while maintaining a diagnostics-first approach. These improvements aim to ensure robust performance, high maintainability, and alignment with the roadmap.

---

## 🚀 Roadmap Features

### 1. Adaptive Volatility Filters
- **Description**: Introduce volatility-based position sizing and entry/exit conditions using advanced metrics such as ATR bands and dynamic throttling.
- **Goals**:
  - Improve trade timing during high-volatility environments.
  - Fine-tune stop-loss/take-profit levels dynamically.
- **Technical Plan**:
  - Extend `drift_detection` scripts with dynamic thresholds.
  - Backtest using multi-regime datasets to quantify impact.
  - Integrate results into dashboards for transparency.

---

### 2. Multi-Symbol Routing
- **Description**: Enable trade routing across multiple symbols and asset classes under a unified EA configuration.
- **Goals**:
  - Expand the EA's capabilities beyond single-symbol operation.
  - Implement prioritization rules for correlated assets.
- **Technical Plan**:
  - Add `symbols.yaml` and implement risk management schema adjustments.
  - Integrate MQL5 trade classes for multi-symbol/multi-position handling.

---

### 3. Advanced Dashboards
- **Description**: Enhance dashboards to include:
  - **Risk Metrics**:
    - Daily drawdowns, weekly volatility, tail risks.
  - **Equity Curve Analytics**:
    - Visualize trends, streaks, and regime alignments.
- **Goals**:
  - Ensure that all contributors have intuitive access to results.
  - Maintain high alignment with diagnostics-first practices.
- **Technical Plan**:
  - Extend `dashboards/multi_run/render_matrix.py` to parse additional schema elements.
  - Standardize dashboard outputs (e.g., JSON -> visual glyphs).

---

## 📈 Milestones

1. **Q4 2025**: Adaptive filters R&D phase, finalize schema for demo configs.
2. **Q1 2026**: Multi-symbol trade routing pilot.
3. **Q2 2026**: Full integration of dashboards, open review for contributor ideas.

---

## ✋ Contributing to the Roadmap
If you'd like to contribute ideas or code to the roadmap:
1. Fork the project and develop a proof-of-concept.
2. Open a feature proposal or draft PR via `CONTRIBUTING.md`.
3. Tag roadmap items with `Roadmap Discussion` and work items with `enhancement`.

Together, we can ensure this EA remains on the cutting edge of trading technology. 🚀