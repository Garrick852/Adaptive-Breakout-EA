from typing import List, Optional
from pydantic import BaseModel, Field

class SymbolSignalConfig(BaseModel):
    symbol: str = Field(..., pattern="^[A-Z]{6}$")
    min_confidence: Optional[float] = Field(None, ge=0.0, le=1.0)
    max_latency_seconds: Optional[int] = Field(None, ge=0)

class GlobalSignalFilters(BaseModel):
    min_confidence: float = Field(..., ge=0.0, le=1.0)
    max_latency_seconds: int = Field(..., ge=0)
    allowed_signals: List[int] = Field(..., min_length=1)

class SignalsConfig(BaseModel):
    source: str = Field(..., pattern="^(ML_MODEL|EXTERNAL_FEED|MANUAL)$")
    horizon: str = Field(..., pattern="^(INTRADAY|SWING|POSITION)$")
    symbols: Optional[List[SymbolSignalConfig]] = None
    filters: GlobalSignalFilters
