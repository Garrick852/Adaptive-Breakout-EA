# Adaptive Breakout EA – Dashboard Backend

Simple FastAPI backend to expose EA configs, routing, and (later) metrics.

## Setup

```bash
cd dashboards/backend
python -m venv .venv
source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Set `MT5_DATA_DIR` in your environment if you want to integrate with a live MT5 terminal:

```bash
export MT5_DATA_DIR="C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\43A9BD896CCB6BF2DF5C71EA198AE39D"
```

## Run

```bash
uvicorn dashboards.backend.app:app --reload
```

Then open http://127.0.0.1:8000/docs for the interactive API docs.
