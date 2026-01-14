import time
from typing import Dict

from bridge.config import POLL_INTERVAL_SEC, MIN_UPDATE_INTERVAL_SEC
from bridge.io.feature_reader import read_latest_features
from bridge.io.signal_writer import write_signal, BridgeSignalError
from bridge.models.example_model import score_features

SYMBOLS = ["XAUUSD"]  # extend as needed later

def main():
    print("[INFO] Starting ML bridge loop")
    last_signal_time: Dict[str, float] = {}

    while True:
        loop_start = time.time()

        for symbol in SYMBOLS:
            try:
                features = read_latest_features(symbol)
                if features is None:
                    continue  # nothing yet

                now = time.time()
                last_t = last_signal_time.get(symbol, 0.0)
                if now - last_t < MIN_UPDATE_INTERVAL_SEC:
                    continue  # rate limit

                signal = score_features(features)
                path = write_signal(signal, symbol=symbol, per_symbol=False)
                last_signal_time[symbol] = now
                print(f"[INFO] symbol={symbol} signal={signal} -> {path}")
            except BridgeSignalError as e:
                print(f"[ERROR] {e}")
                time.sleep(5)
            except Exception as e:
                print(f"[ERROR] Unexpected error for symbol {symbol}: {e}")

        # Sleep for the remaining interval
        elapsed = time.time() - loop_start
        sleep_time = max(0.0, POLL_INTERVAL_SEC - elapsed)
        time.sleep(sleep_time)

if __name__ == "__main__":
    main()
