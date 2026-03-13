#!/usr/bin/env bash
# Gracefully stop the test server.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/server.pid"

if [[ ! -f "$PID_FILE" ]]; then
    echo "[INFO]  No server PID file found — server is probably not running."
    exit 0
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
    echo "[INFO]  Stopping server (PID $PID)..."
    # Send SIGTERM — Paper handles this as a graceful /stop
    kill "$PID"
    # Wait up to 30 seconds for a clean shutdown
    for i in $(seq 1 30); do
        if ! kill -0 "$PID" 2>/dev/null; then
            echo "[INFO]  Server stopped cleanly."
            rm -f "$PID_FILE"
            exit 0
        fi
        sleep 1
    done
    echo "[WARN]  Server did not stop in 30s — force-killing..."
    kill -9 "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
else
    echo "[INFO]  No process with PID $PID found — already stopped."
    rm -f "$PID_FILE"
fi
