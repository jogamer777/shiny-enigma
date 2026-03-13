#!/usr/bin/env bash
# Start the test server in the background and tail the log.
# The server is ready when you see "Done" in the output.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"
PID_FILE="$SCRIPT_DIR/server.pid"
LOG_FILE="$SERVER_DIR/logs/latest.log"

if [[ ! -f "$SERVER_DIR/paper.jar" ]]; then
    echo "[ERROR] paper.jar not found. Run: bash test/setup.sh first."
    exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "[WARN]  Server is already running (PID $(cat "$PID_FILE"))."
    exit 0
fi

mkdir -p "$SERVER_DIR/logs"
cd "$SERVER_DIR"

echo "[INFO]  Starting server..."
java -Xmx1G -Xms512M \
    -XX:+UseG1GC \
    -jar paper.jar --nogui \
    > "$LOG_FILE" 2>&1 &

echo $! > "$PID_FILE"
echo "[INFO]  Server PID: $(cat "$PID_FILE")"
echo "[INFO]  Tailing log — waiting for 'Done' message..."
echo "[INFO]  (Ctrl+C to stop tailing; server keeps running)"
echo ""

# Tail log until "Done" appears
tail -f "$LOG_FILE" | while IFS= read -r line; do
    echo "$line"
    if [[ "$line" == *"Done ("* ]]; then
        echo ""
        echo "[INFO]  ✓ Server is ready! You can now run: bash test/run-tests.sh"
        # Kill only the tail, not the server
        kill "$(pgrep -f "tail -f $LOG_FILE")" 2>/dev/null || true
        break
    fi
done

wait 2>/dev/null || true
