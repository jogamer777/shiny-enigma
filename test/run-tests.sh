#!/usr/bin/env bash
# =============================================================================
# shiny-enigma — RCON Test Runner
#
# Sends commands to the running test server via RCON, checks the server log
# for expected output, and reports PASS / FAIL for each test case.
#
# Usage:  bash test/run-tests.sh
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/server"
LOG_FILE="$SERVER_DIR/logs/latest.log"

export RCON_HOST="${RCON_HOST:-127.0.0.1}"
export RCON_PORT="${RCON_PORT:-25575}"
export RCON_PASSWORD="${RCON_PASSWORD:-testpassword123}"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[1;33m'
BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; SKIP=0

# --- Helpers -----------------------------------------------------------------

rcon() {
    python3 "$SCRIPT_DIR/rcon.py" "$@" 2>&1
}

# Wait up to $3 seconds for $2 pattern to appear in log after running $1 command
assert_log() {
    local description="$1"
    local command="$2"
    local expected_pattern="$3"
    local timeout="${4:-5}"

    # Record log position BEFORE sending the command so we only match NEW entries
    local start_line
    start_line=$(wc -l < "$LOG_FILE")

    rcon "$command" > /dev/null 2>&1
    local deadline=$((SECONDS + timeout))
    while [[ $SECONDS -lt $deadline ]]; do
        if tail -n +"$((start_line + 1))" "$LOG_FILE" | grep -q "$expected_pattern"; then
            echo -e "  ${GREEN}PASS${NC}  $description"
            ((PASS++))
            return 0
        fi
        sleep 0.5
    done
    echo -e "  ${RED}FAIL${NC}  $description"
    echo -e "        Expected pattern in log: '$expected_pattern'"
    ((FAIL++))
    return 1
}

# Check RCON response directly
assert_response() {
    local description="$1"
    local command="$2"
    local expected_pattern="$3"

    local response
    response=$(rcon "$command" 2>&1)
    if echo "$response" | grep -qi "$expected_pattern"; then
        echo -e "  ${GREEN}PASS${NC}  $description"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}  $description"
        echo -e "        Command:  $command"
        echo -e "        Response: $response"
        echo -e "        Expected: $expected_pattern"
        ((FAIL++))
    fi
}

# Just run an RCON command, don't check (used for state setup)
run() {
    rcon "$@" > /dev/null 2>&1 || true
}

wait_seconds() {
    echo -e "  ${YELLOW}....${NC}  Waiting $1s..."
    sleep "$1"
}

# --- Pre-check ---------------------------------------------------------------

echo ""
echo -e "${BOLD}shiny-enigma — Test Suite${NC}"
echo "────────────────────────────────────────"

if [[ ! -f "$LOG_FILE" ]]; then
    echo "[ERROR] Server log not found. Is the server running? (bash test/start.sh)"
    exit 1
fi

echo -e "  Connecting to RCON at $RCON_HOST:$RCON_PORT..."
if ! python3 "$SCRIPT_DIR/rcon.py" "list" &>/dev/null; then
    echo -e "  ${RED}[ERROR]${NC} Cannot connect to RCON."
    echo "          Make sure the server is fully started and RCON is enabled."
    exit 1
fi
echo -e "  ${GREEN}RCON connected.${NC}"
echo ""

# =============================================================================
# SUITE 1 — Skript loaded correctly
# =============================================================================
echo -e "${BOLD}[1] Skript sanity checks${NC}"

assert_log \
    "Skript loaded without errors" \
    "sk reload all" \
    "loaded.*without errors\|0 error\|Successfully loaded" \
    15

# =============================================================================
# SUITE 2 — Phase state machine (uses /sktest commands from test-commands.sk)
# =============================================================================
echo ""
echo -e "${BOLD}[2] Phase state machine${NC}"

assert_log \
    "/sktest phases — initial phase is 1" \
    "sktest phases" \
    "PHASE_TEST.*phase=1" \
    5

assert_log \
    "/setstartphase1 resets to phase 1" \
    "setstartphase1" \
    "Setup phase started" \
    5

# Manually advance to phase 2 (startphase1 needs a player; test directly)
assert_log \
    "Phase variable sets to 2 after /sktest setphase 2" \
    "sktest setphase 2" \
    "PHASE_TEST.*phase=2" \
    5

assert_log \
    "Phase variable sets to 3 after /sktest setphase 3" \
    "sktest setphase 3" \
    "PHASE_TEST.*phase=3" \
    5

assert_log \
    "Phase variable sets to 4 after /sktest setphase 4" \
    "sktest setphase 4" \
    "PHASE_TEST.*phase=4" \
    5

assert_log \
    "/resetgame resets phase to 1" \
    "resetgame" \
    "Game has been fully reset" \
    5

assert_log \
    "Phase is 1 again after reset" \
    "sktest phases" \
    "PHASE_TEST.*phase=1" \
    5

# =============================================================================
# SUITE 3 — Bed status
# =============================================================================
echo ""
echo -e "${BOLD}[3] Bed status & winner detection${NC}"

assert_log \
    "Bed status initialised as true/true after reset" \
    "sktest bedstatus" \
    "BED_TEST.*red=true.*blue=true" \
    5

assert_log \
    "Simulate blue bed destroyed — red should win" \
    "sktest killbed blue" \
    "BED_TEST.*blue=false" \
    5

assert_log \
    "/endgame announces Team Red as winner" \
    "endgame" \
    "Team Red wins" \
    5

# =============================================================================
# SUITE 4 — Respawn counter
# =============================================================================
echo ""
echo -e "${BOLD}[4] Respawn logic${NC}"

assert_log \
    "/sktest respawns — default respawns=3 for test player" \
    "sktest respawns TestPlayer" \
    "RESPAWN_TEST.*TestPlayer.*3" \
    5

assert_log \
    "/sktest addrespawn — respawn count increases to 4" \
    "sktest addrespawn TestPlayer" \
    "RESPAWN_TEST.*TestPlayer.*4" \
    5

assert_log \
    "/sktest subrespawn — respawn count decreases to 3" \
    "sktest subrespawn TestPlayer" \
    "RESPAWN_TEST.*TestPlayer.*3" \
    5

# =============================================================================
# SUITE 5 — Variable integrity after reload
# =============================================================================
echo ""
echo -e "${BOLD}[5] Variable integrity after /sk reload${NC}"

run "sktest setphase 3"
assert_log \
    "Phase survives script reload" \
    "sk reload all" \
    "loaded.*without errors\|0 error\|Successfully loaded" \
    15

assert_log \
    "Phase is still 3 after reload" \
    "sktest phases" \
    "PHASE_TEST.*phase=3" \
    5

# Reset for clean state
run "resetgame"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "────────────────────────────────────────"
TOTAL=$((PASS + FAIL + SKIP))
echo -e "${BOLD}Results: ${GREEN}$PASS passed${NC}, ${RED}$FAIL failed${NC}, ${YELLOW}$SKIP skipped${NC} (total: $TOTAL)"
echo ""

if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}Some tests failed. Check the server log for details:${NC}"
    echo "  tail -n 100 $LOG_FILE"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi
