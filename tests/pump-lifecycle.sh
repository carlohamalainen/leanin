#!/usr/bin/env bash
# The pump thread must restart for a timer armed after it retired, and must not hold the process open for a
# cancelled deadline. Exit 2 is a setup failure (the build, or the watchdog not catching the stranded control);
# exit 1 is a case that did not finish.
#   nix develop -c bash tests/pump-lifecycle.sh
set -uo pipefail
cd "$(dirname "$0")/.."
lake build pumpLifecycle >/dev/null || { echo "pump-lifecycle: setup: build failed"; exit 2; }
bin=.lake/build/bin/pumpLifecycle
watchdog=5
timeout "$watchdog" "$bin" control >/dev/null
status=$?
[ "$status" -eq 124 ] || { echo "pump-lifecycle: setup: the stranded control read status $status, not 124"; exit 2; }
failed=0
for c in rearm two-runs won-timeout; do
  out=$(timeout "$watchdog" "$bin" "$c")
  status=$?
  if [ "$status" -eq 0 ] && grep -q "case=$c|done=yes" <<<"$out"; then
    echo "$c: ok"
  else
    echo "$c: did not finish (status $status)"
    failed=1
  fi
done
[ "$failed" -eq 0 ] || exit 1
echo "pump-lifecycle: ok"
