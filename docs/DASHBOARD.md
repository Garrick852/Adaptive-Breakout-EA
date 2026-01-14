# Dashboard

The dashboard is an optional control plane for:

- Viewing effective EA config
- Inspecting router configuration
- (Later) monitoring metrics and trade stats

## Backend

Located in `dashboards/backend`.

### Setup

```bash
cd dashboards/backend
python -m venv .venv
source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Optionally set `MT5_DATA_DIR` to point to your MT5 Data Folder:

```bash
export MT5_DATA_DIR="C:\Users\User\AppData\Roaming\MetaQuotes\Terminal\<hash>"
```

### Run

```bash
uvicorn dashboards.backend.app:app --reload
```

Open http://127.0.0.1:8000/docs to explore the API.

## Frontend

Located in `dashboards/frontend`. Currently a placeholder; you can implement React/Vue/etc. here and point it at the backend API.
