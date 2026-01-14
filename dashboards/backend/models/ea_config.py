from pydantic import BaseModel, Field

class EAConfig(BaseModel):
    atr_period: int = Field(..., ge=1, le=1000)
    atr_mult_sl: float = Field(..., ge=0.1, le=20)
    atr_mult_tp: float = Field(..., ge=0.1, le=50)
    min_atr_filter: float = Field(..., ge=0.0)

    box_mode: str = Field(..., pattern="^(DONCHIAN|TIMERANGE)$")
    box_lookback_bars: int = Field(..., ge=2, le=10000)
    time_from_hour: int = Field(..., ge=0, le=23)
    time_to_hour: int = Field(..., ge=0, le=23)

    breakout_buffer_pts: float = Field(..., ge=0.0)
    require_close_beyond: bool

    risk_percent_per_trade: float = Field(..., ge=0.01, le=5.0)
    use_pending_orders: bool
    use_atr_trail: bool
    atr_trail_mult: float = Field(..., ge=0.0)
