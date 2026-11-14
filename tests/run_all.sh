#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .artifacts/logs
GODOT="${GODOT:-$(command -v godot4 || command -v godot || true)}"
if [[ -z "$GODOT" ]]; then echo 'BLOCKED: set GODOT to a Godot 4 executable'; exit 2; fi
"$GODOT" --version | tee .artifacts/logs/engine.txt
python3 tests/reference_check.py | tee .artifacts/logs/reference.txt
run() {
  local name="$1"; shift
  timeout 45s "$GODOT" --headless --path "$PWD" "$@" 2>&1 | tee ".artifacts/logs/$name.txt"
  if grep -E 'SCRIPT ERROR|Parse Error|^ERROR:|^FAIL ' ".artifacts/logs/$name.txt"; then exit 1; fi
}
run import --editor --import --quit
run regression --script res://tests/run.gd --quit-after 120
grep -E 'RESULT: [0-9]+ passed, 0 failed' .artifacts/logs/regression.txt
run main_smoke --quit-after 10
run presentation --script res://tests/presentation.gd --quit-after 120
grep -F "Presentation failures: 0" .artifacts/logs/presentation.txt
run d1 --script res://tests/d1.gd --quit-after 120
grep -F "D1 failures: 0" .artifacts/logs/d1.txt
run d2 --script res://tests/d2.gd --quit-after 120
grep -F "D2 failures: 0" .artifacts/logs/d2.txt
run week --script res://tests/week.gd --quit-after 120
grep -E "WEEK RESULT: [0-9]+ passed, 0 failed" .artifacts/logs/week.txt
run week_ui --script res://tests/week_ui.gd --quit-after 120
grep -E "WEEK UI RESULT: [0-9]+ passed, 0 failed" .artifacts/logs/week_ui.txt
run resolution_smoke res://ui/ResolutionCompare.tscn --quit-after 10
printf '\nRuntime gate passed. Manual playtest still required.\n'
