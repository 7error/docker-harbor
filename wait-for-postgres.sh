#!/bin/bash -e
# wait-for-postgres.sh
# Adapted from https://docs.docker.com/compose/startup-order/

# Expects the necessary PG* variables.

until psql -c '\l' -U "postgres" -tw >/dev/null 2>&1; do
  echo >&2 "$(date +%Y%m%dt%H%M%S) Postgres is unavailable - sleeping"
  sleep 4
done
echo >&2 "$(date +%Y%m%dt%H%M%S) Postgres is up - executing command"

exec ${@}