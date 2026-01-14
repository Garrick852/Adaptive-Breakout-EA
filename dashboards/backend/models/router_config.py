from typing import List, Optional
from pydantic import BaseModel, Field

class RouteConfig(BaseModel):
    symbol: str = Field(..., pattern="^[A-Z]{6}$")
    strategy: str = Field(..., pattern="^(BREAKOUT|MEANREVERT|AUTO)$")
    priority: str = Field(..., pattern="^(LOW|MEDIUM|HIGH)$")
    ai_enabled: bool = True
    drift_enabled: bool = True
    fallback_strategy: str = Field(..., pattern="^(BREAKOUT|MEANREVERT)$")
    confidence_threshold: Optional[float] = Field(None, ge=0.0, le=1.0)

class RouterDefaultConfig(BaseModel):
    strategy: str = Field(..., pattern="^(BREAKOUT|MEANREVERT|AUTO)$")
    ai_enabled: bool = True
    drift_enabled: bool = True
    fallback_strategy: str = Field(..., pattern="^(BREAKOUT|MEANREVERT)$")
    confidence_threshold: Optional[float] = Field(None, ge=0.0, le=1.0)

class RouterConfig(BaseModel):
    routes: List[RouteConfig]
    default: RouterDefaultConfig
