#!/usr/bin/env bash
#
# Brings up Nakama + Postgres + Redis via docker compose.
# Acceptance: Nakama dashboard reachable at http://localhost:7351 after this completes.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Run scripts/setup.sh first."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose v2 not found (need 'docker compose', not 'docker-compose')."
  exit 1
fi

echo "Starting services (Nakama, Postgres, Redis)..."
docker compose up -d

echo
echo "Waiting up to 90s for Nakama health check..."
deadline=$(( $(date +%s) + 90 ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  status=$(docker inspect --format='{{.State.Health.Status}}' words-poker-nakama 2>/dev/null || echo "missing")
  case "$status" in
    healthy)
      echo
      echo "Nakama is up."
      echo "  Dashboard:  http://localhost:7351  (default login: admin / password)"
      echo "  Client API: http://localhost:7350"
      echo "  gRPC API:   localhost:7349"
      echo "  Postgres:   localhost:5432  (db=nakama user=postgres password=localdev)"
      echo "  Redis:      localhost:6379"
      echo
      echo "Logs:  docker compose logs -f nakama"
      echo "Stop:  docker compose down"
      exit 0
      ;;
    starting|missing)
      sleep 3
      ;;
    *)
      echo "Nakama health status: $status"
      sleep 3
      ;;
  esac
done

echo
echo "ERROR: Nakama did not become healthy within 90s."
echo "Check logs:  docker compose logs nakama"
exit 1
