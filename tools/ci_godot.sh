#!/usr/bin/env bash
# Runs headless Godot with the given arguments and fails when it exits non-zero, or when its
# output shows a script error or objects leaked at exit, which Godot reports without failing.
set -uo pipefail
log=$(mktemp)
timeout 900 "${GODOT:-$HOME/godot/godot}" --headless --path . "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
if grep -qE "SCRIPT ERROR|instances were leaked|resources still in use|RID allocations of type .* were leaked|RIDs of type .* were leaked" "$log"; then
  echo "::error::Godot reported script errors or leaks (see above)"
  exit 1
fi
exit "$status"
