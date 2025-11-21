# Glyph: DriftDetected

## Description

The `DriftDetected` glyph is a critical alert emitted by the `drift_detection.mqh` module. It signifies that the predictive performance of the `CalculateSensitivityScore` model has degraded below a predefined threshold.

When this glyph is emitted, the Expert Advisor should take protective action, such as halting new trade entries until the model is recalibrated or the market conditions change.

## Format

- **Type**: `string`
- **Value**: A descriptive string explaining the nature of the drift.

## Example Output

```
Glyph emitted: DriftDetected - SensitivityScore performance has degraded!
```

## CI Validation Requirements

The GitHub Actions workflow for CI must perform a backtest that intentionally triggers this condition. The workflow should then parse the backtest logs and verify that:
1. The `DriftDetected` glyph is present in the output.
2. The format of the glyph matches the example provided above.

Failure to meet these conditions should result in a failed CI check.
