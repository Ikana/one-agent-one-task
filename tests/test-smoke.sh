#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SCAFFOLD="$ROOT_DIR/scripts/scaffold.sh"
SMOKE="$ROOT_DIR/scripts/smoke-test.sh"
TMP_DIR=""

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

main() {
  command -v jq >/dev/null 2>&1 || fail "jq is required"

  local valid_dir
  local broken_dir
  local valid_output
  local broken_output

  TMP_DIR=$(mktemp -d)
  trap 'rm -rf "$TMP_DIR"' EXIT

  valid_dir="$TMP_DIR/valid"
  "$SCAFFOLD" valid \
    --coord-path "$valid_dir/coord" \
    --output-dir "$valid_dir" >/dev/null

  valid_output=$("$SMOKE" "$valid_dir" --skip-docker)
  [[ $valid_output == *"checks passed"* ]] || fail "Smoke test did not report a passing summary"
  [[ -f $valid_dir/coord/status/smoke-test.json ]] || fail "Smoke test did not write coord/status/smoke-test.json"
  jq -e '.passed == true and (.checks | length == 6)' "$valid_dir/coord/status/smoke-test.json" >/dev/null || fail "Smoke test status payload is invalid"

  jq -e '.passed == true and (.summary | test("checks passed$"))' >/dev/null <<<"$("$SMOKE" "$valid_dir" --skip-docker --json)" || fail "JSON output contract check failed"

  broken_dir="$TMP_DIR/broken"
  "$SCAFFOLD" broken \
    --coord-path "$broken_dir/coord" \
    --output-dir "$broken_dir" >/dev/null
  rm -rf "$broken_dir/coord/signals/communicator"

  if broken_output=$("$SMOKE" "$broken_dir" --skip-docker --verbose 2>&1); then
    fail "Smoke test should fail for a broken project"
  fi

  [[ $broken_output == *"directory_structure"* ]] || fail "Broken smoke test output did not mention directory_structure"
  [[ $broken_output == *"coord/signals/communicator"* ]] || fail "Broken smoke test output did not name the missing directory"

  printf 'test-smoke.sh: PASS\n'
}

main "$@"
