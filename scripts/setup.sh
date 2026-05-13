#!/usr/bin/env bash
#
# Verifies local toolchain prerequisites for Words Poker development.
# Prints install hints for anything missing; does NOT auto-install (OS-specific).

set -uo pipefail

check() {
  local cmd=$1
  local hint=$2
  local version_flag=${3:---version}
  if command -v "$cmd" >/dev/null 2>&1; then
    local v
    v=$("$cmd" $version_flag 2>&1 | head -1)
    echo "  [ok]   $cmd  ($v)"
    return 0
  else
    echo "  [MISS] $cmd"
    echo "         install: $hint"
    return 1
  fi
}

missing=0

echo "Checking toolchain..."
check go      "https://go.dev/dl/ (need 1.22+)"                              version || missing=$((missing+1))
check python3 "https://www.python.org/downloads/ or 'brew install python@3.11' (need 3.11+)" || missing=$((missing+1))
check docker  "https://docs.docker.com/get-docker/"                                          || missing=$((missing+1))

# docker compose ships as a docker plugin; check it explicitly.
if docker compose version >/dev/null 2>&1; then
  echo "  [ok]   docker compose v2  ($(docker compose version | head -1))"
else
  echo "  [MISS] docker compose v2"
  echo "         install: comes with Docker Desktop, or 'apt install docker-compose-plugin'"
  missing=$((missing+1))
fi

echo

if [ "$missing" -gt 0 ]; then
  echo "$missing tool(s) missing. Install them and re-run: bash scripts/setup.sh"
  exit 1
fi

echo "All prerequisites present. Next:  bash scripts/run_local.sh"
