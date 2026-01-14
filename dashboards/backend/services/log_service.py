from pathlib import Path

from dashboards.backend.config.settings import EA_LOG_PATH, MT5_DATA_DIR


class LogError(RuntimeError):
    pass

def tail_file(path: Path, max_lines: int = 200) -> list[str]:
    """
    Read last `max_lines` lines from `path` efficiently.
    If file is shorter than `max_lines`, return all lines.
    """
    if not path.exists():
        raise LogError(f"Log file not found: {path}")

    # Simple implementation: read all, slice from the end
    # For huge logs, you could implement a more efficient seek-based tail.
    text = path.read_text(encoding="utf-8", errors="ignore")
    lines = text.splitlines()
    if len(lines) <= max_lines:
        return lines
    return lines[-max_lines:]

def get_ea_log_tail(max_lines: int = 200) -> dict:
    """
    Returns a dict with metadata + lines.
    """
    if MT5_DATA_DIR is None or EA_LOG_PATH is None:
        raise LogError(
            "MT5_DATA_DIR is not configured, or EA_LOG_PATH is not set. "
            "Set MT5_DATA_DIR env var and ensure the EA writes a log."
        )

    lines = tail_file(EA_LOG_PATH, max_lines=max_lines)
    return {
        "path": str(EA_LOG_PATH),
        "lines": lines,
        "count": len(lines),
    }
