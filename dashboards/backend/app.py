from fastapi import FastAPI, HTTPException

from dashboards.backend.models.ea_config import EAConfig
from dashboards.backend.models.router_config import RouterConfig
from dashboards.backend.models.signal import SignalRequest
from dashboards.backend.services.config_service import load_and_validate
from dashboards.backend.services.router_service import get_router_config
from dashboards.backend.services.metrics_service import get_dummy_metrics
from dashboards.backend.services.signal_service import write_signal, SignalWriteError

app = FastAPI(title="Adaptive Breakout EA Dashboard API")

# ... existing endpoints ...

@app.post("/signals/simple")
def post_simple_signal(req: SignalRequest):
    """
    Write a global ai_signal.txt for the EA to read.
    """
    try:
        path = write_signal(req, per_symbol=False)
        return {"status": "ok", "path": str(path), "signal": req.signal, "symbol": req.symbol}
    except SignalWriteError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/signals/{symbol}")
def post_symbol_signal(symbol: str, req: SignalRequest):
    """
    Write a per-symbol ai_signal_<symbol>.txt for the EA to read.
    Note: EA must be implemented to read per-symbol files if you want to use this.
    """
    # Override symbol in request with path parameter
    req.symbol = symbol.upper()
    try:
        path = write_signal(req, per_symbol=True)
        return {"status": "ok", "path": str(path), "signal": req.signal, "symbol": req.symbol}
    except SignalWriteError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
