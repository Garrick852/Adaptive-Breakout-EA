
from pydantic import BaseModel, Field


class SymbolSignalConfig(BaseModel):
    symbol: str = Field(..., pattern="^[A-Z]{6}$")
    min_confidence: float | None = Field(None, ge=0.0, le=1.0)
    max_latency_seconds: int | None = Field(None, ge=0)

class GlobalSignalFilters(BaseModel):
    min_confidence: float = Field(..., ge=0.0, le=1.0)
    max_latency_seconds: int = Field(..., ge=0)
    allowed_signals: list[int] = Field(..., min_length=1)

class SignalsConfig(BaseModel):
    source: str = Field(..., pattern="^(ML_MODEL|EXTERNAL_FEED|MANUAL)$")
    horizon: str = Field(..., pattern="^(INTRADAY|SWING|POSITION)$")
    symbols: list[SymbolSignalConfig] | None = None
    filters: GlobalSignalFilters
