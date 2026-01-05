#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

EA_NAME = "AdaptiveBreakoutAI"
EA_SOURCE = Path("eas/AdaptiveBreakoutAI/src/AdaptiveBreakoutAI.mq5")

MT5_TERMINAL_DIR = os.environ.get("MT5_TERMINAL_DIR", "")
METAEDITOR_EXE   = os.environ.get("METAEDITOR_EXE", "")

def fail(msg: str, code: int = 1):
    print(f"[ERROR] {msg}", file=sys.stderr)
    sys.exit(code)

def ensure_paths():
    if not EA_SOURCE.is_file():
        fail(f"EA source not found: {EA_SOURCE}")

    if not MT5_TERMINAL_DIR:
        fail("MT5_TERMINAL_DIR env var not set")
    if not METAEDITOR_EXE:
        fail("METAEDITOR_EXE env var not set")

    term = Path(MT5_TERMINAL_DIR)
    if not term.is_dir():
        fail(f"MT5_TERMINAL_DIR not found: {term}")

    me = Path(METAEDITOR_EXE)
    if not me.is_file():
        fail(f"METAEDITOR_EXE not found: {me}")

    return term, me

def copy_ea_to_terminal(term_dir: Path):
    experts_dir = term_dir / "MQL5" / "Experts" / EA_NAME
    include_dir = term_dir / "MQL5" / "Include" / EA_NAME
    experts_dir.mkdir(parents=True, exist_ok=True)
    include_dir.mkdir(parents=True, exist_ok=True)

    src_dir = EA_SOURCE.parent

    for f in src_dir.iterdir():
        if f.suffix.lower() == ".mq5":
            (experts_dir / f.name).write_bytes(f.read_bytes())
        elif f.suffix.lower() == ".mqh":
            for d in (experts_dir, include_dir):
                (d / f.name).write_bytes(f.read_bytes())

    return experts_dir / EA_SOURCE.name

def compile_ea(metaeditor: Path, ea_path: Path) -> int:
    log_file = ea_path.with_suffix(".log")
    cmd = [str(metaeditor), f"/compile:{ea_path}", f"/log:{log_file}"]
    print("[INFO] Running:", " ".join(cmd))
    proc = subprocess.run(cmd, capture_output=True, text=True)
    print(proc.stdout)
    print(proc.stderr, file=sys.stderr)

    if not log_file.exists():
        fail(f"MetaEditor log not produced: {log_file}")

    log_text = log_file.read_text(encoding="utf-8", errors="ignore")
    print("----- MetaEditor Log -----")
    print(log_text)
    print("--------------------------")

    lowered = log_text.lower()
    if " error " in lowered or " errors " in lowered:
        print("[ERROR] Compilation errors detected")
        return 1

    print("[OK] EA compiled successfully")
    return 0

def main():
    term_dir, metaeditor = ensure_paths()
    ea_dest = copy_ea_to_terminal(term_dir)
    code = compile_ea(metaeditor, ea_dest)
    sys.exit(code)

if __name__ == "__main__":
    main()
