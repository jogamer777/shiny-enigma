# Claw Bot — Test Instructions for shiny-enigma

This document tells you exactly what to do to set up and test the
shiny-enigma Minecraft Skript plugin on this machine (Bazzite).

---

## What you need to do (summary)

1. Install Java 21 (if not already installed)
2. Run the server setup script — it downloads everything automatically
3. Start the server
4. Run the automated test suite
5. Report the results

---

## Step-by-step

### Step 1 — Check Java

```bash
java -version
```

**Expected:** output contains `version "21` or higher.

If Java is missing or too old, run:

```bash
rpm-ostree install java-21-openjdk-headless
```

Then **reboot** and come back to Step 1.

---

### Step 2 — Run the server setup script

From the repository root (`shiny-enigma/`):

```bash
bash test/setup.sh
```

This will:
- Download the latest Paper 1.21.4 server jar
- Download Skript, WorldGuard, WorldEdit, LuckPerms, Citizens plugins
- Copy the `.sk` game scripts into the server
- Write a `server.properties` with RCON enabled

**Watch for warnings:** some plugins (Citizens, WorldEdit) may fail to
auto-download. If you see a warning, download them manually and place
the `.jar` files in `test/server/plugins/`.

---

### Step 3 — Start the server

```bash
bash test/start.sh
```

The script starts Paper in the background and tails the log.
Wait until you see a line like:

```
[XX:XX:XX INFO]: Done (12.345s)! For help, type "help"
```

Then the server is ready. Press **Ctrl+C** to stop tailing
(the server keeps running).

If the server crashes on startup, check the log:

```bash
cat test/server/logs/latest.log
```

Common causes:
- Java version too old (needs 21+)
- Missing plugin dependency (e.g. WorldEdit required by WorldGuard)
- Port 25565 already in use → change `server-port` in `test/server/server.properties`

---

### Step 4 — Run the automated tests

```bash
bash test/run-tests.sh
```

The test runner connects to the server via RCON, sends commands, and
checks the server log for expected output patterns.

**Expected output (all passing):**

```
shiny-enigma — Test Suite
────────────────────────────────────────
  RCON connected.

[1] Skript sanity checks
  PASS  Skript loaded without errors
  PASS  No Skript errors after reload

[2] Phase state machine
  PASS  /sktest phases — initial phase is 1
  PASS  /setstartphase1 resets to phase 1
  PASS  Phase variable sets to 2 after /sktest setphase 2
  PASS  Phase variable sets to 3 after /sktest setphase 3
  PASS  Phase variable sets to 4 after /sktest setphase 4
  PASS  /resetgame resets phase to 1
  PASS  Phase is 1 again after reset

[3] Bed status & winner detection
  PASS  Bed status initialised as true/true after reset
  PASS  Simulate blue bed destroyed — red should win
  PASS  /endgame announces Team Red as winner

[4] Respawn logic
  PASS  default respawns=3 for test player
  PASS  respawn count increases to 4
  PASS  respawn count decreases to 3

[5] Variable integrity after /sk reload
  PASS  Phase survives script reload
  PASS  Phase is still 3 after reload

────────────────────────────────────────
Results: 17 passed, 0 failed, 0 skipped (total: 17)

All tests passed!
```

---

### Step 5 — If tests fail

For any `FAIL` line, the test runner prints the expected pattern and
the actual server response. Check the full log for context:

```bash
tail -n 100 test/server/logs/latest.log
```

You can also run individual test commands manually using the RCON client:

```bash
# Send any command to the running server:
python3 test/rcon.py "sktest vars"
python3 test/rcon.py "sktest phases"
python3 test/rcon.py "sk reload all"

# List online players:
python3 test/rcon.py "list"
```

---

### Step 6 — Stop the server when done

```bash
bash test/stop.sh
```

---

## Useful one-liners

| What | Command |
|------|---------|
| Reload scripts only | `python3 test/rcon.py "sk reload all"` |
| Check current phase | `python3 test/rcon.py "sktest phases"` |
| Dump all variables | `python3 test/rcon.py "sktest vars"` |
| Check bed status | `python3 test/rcon.py "sktest bedstatus"` |
| Simulate blue bed gone | `python3 test/rcon.py "sktest killbed blue"` |
| Check server log live | `tail -f test/server/logs/latest.log` |

---

## Notes

- The server runs in **offline mode** (no Minecraft account needed)
- RCON password is `testpassword123` (only for local testing)
- The `test-commands.sk` file contains extra `/sktest` commands —
  **do not copy this file to a production server**
- All coordinates in `game.sk` are placeholders; the logic tests
  (phases, beds, respawns) work without a real map
