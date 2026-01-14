from typing import Dict

def score_features(features: Dict[str, float]) -> int:
    """
    Dummy model:
      - If close > box_upper -> +1
      - If close < box_lower -> -1
      - Otherwise -> 0

    Replace with real ML model call later.
    """
    close = features.get("close")
    box_upper = features.get("box_upper")
    box_lower = features.get("box_lower")

    if close is None or box_upper is None or box_lower is None:
        return 0

    if close > box_upper:
        return 1
    if close < box_lower:
        return -1
    return 0
