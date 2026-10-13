#!/usr/bin/env bash
# Shared helpers for every episode's verify.sh.
# Usage:
#   source "$(dirname "$0")/../../scripts/lib.sh"
#   check "description" "command that must exit 0" "optional hint on failure"
#   summary

PASS=0
FAIL=0

GREEN='\033[0;32m'
RED='\033[0;31m'
DIM='\033[2m'
RESET='\033[0m'

check() {
  local desc="$1" cmd="$2" hint="${3:-}"
  if eval "$cmd" >/dev/null 2>&1; then
    printf "${GREEN}  PASS${RESET}  %s\n" "$desc"
    PASS=$((PASS + 1))
  else
    printf "${RED}  FAIL${RESET}  %s\n" "$desc"
    [ -n "$hint" ] && printf "${DIM}        hint: %s${RESET}\n" "$hint"
    FAIL=$((FAIL + 1))
  fi
}

summary() {
  echo
  if [ "$FAIL" -eq 0 ]; then
    printf "${GREEN}All %d checks passed.${RESET}\n" "$PASS"
    exit 0
  fi
  printf "${RED}%d of %d checks failed.${RESET}\n" "$FAIL" "$((PASS + FAIL))"
  echo "See docs/TROUBLESHOOTING.md in the repo root, or open an issue with this output."
  exit 1
}
