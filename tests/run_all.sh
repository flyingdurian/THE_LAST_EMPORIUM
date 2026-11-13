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
  "$GODOT" --headless --path "$PWD" "$@" 2>&1 | tee ".artifacts/logs/$name.txt"
  if grep -E 'SCRIPT ERROR|Parse Error|^ERROR:|^FAIL ' ".artifacts/logs/$name.txt"; then exit 1; fi
}
run import --editor --import --quit
run regression --script res://tests/run.gd
grep -E 'RESULT: [0-9]+ passed, 0 failed' .artifacts/logs/regression.txt
run main_smoke --quit-after 10
run presentation --script res://tests/presentation.gd
run d1 --script res://tests/d1.gd
run resolution_smoke res://ui/ResolutionCompare.tscn --quit-after 10
printf '\nRuntime gate passed. Manual playtest still required.\n'
