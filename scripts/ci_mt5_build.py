import os
import subprocess
import sys

# Adjust these for your environment
METAEDITOR_EXE = r"C:\Program Files\MetaTrader 5\metaeditor64.exe"
# Or wherever your MetaEditor is installed

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EA_SOURCE = os.path.join(BASE_DIR, "eas", "AdaptiveBreakoutAI", "src", "AdaptiveBreakoutAI.mq5")

def build_ea():
    if not os.path.exists(METAEDITOR_EXE):
        print(f"[ERROR] MetaEditor not found: {METAEDITOR_EXE}")
        return False
    if not os.path.exists(EA_SOURCE):
        print(f"[ERROR] EA source not found: {EA_SOURCE}")
        return False

    # MetaEditor CLI example:
    # metaeditor64.exe /compile:<file> /log:<logfile>
    log_path = os.path.join(BASE_DIR, "build_mt5.log")

    cmd = [
        METAEDITOR_EXE,
        "/compile:" + EA_SOURCE,
        "/log:" + log_path,
    ]

    print("[INFO] Running:", " ".join(cmd))
    result = subprocess.run(cmd)

    if result.returncode != 0:
        print(f"[ERROR] MetaEditor returned non-zero exit code: {result.returncode}")
        if os.path.exists(log_path):
            print("[INFO] Build log:")
            with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                print(f.read())
        return False

    print("[OK] EA compiled successfully")
    return True

def main():
    if not build_ea():
        sys.exit(1)

if __name__ == "__main__":
    main()
