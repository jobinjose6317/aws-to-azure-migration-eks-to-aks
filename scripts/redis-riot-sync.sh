#!/usr/bin/env bash
# UNTESTED RECONSTRUCTION. Not run as written.
# Live-sync a Redis (cluster mode) from AWS to Azure with RIOT, then verify.
# Usage: SRC=<src-node-ip> DST=<dst-node-ip> ./redis-riot-sync.sh start|verify|stop
set -euo pipefail
: "${SRC:?}" "${DST:?}"; PORT="${PORT:-6379}"; NAME="riot-${SRC//./-}"
IMG="fieldengineering/riot"

case "${1:?start|verify|stop}" in
  start)
    redis-cli -c -h "$SRC" -p "$PORT" CONFIG SET notify-keyspace-events KEA
    docker run -d --name "$NAME" --network host "$IMG" \
      -c -h "$SRC" -p "$PORT" replicate -c -h "$DST" -p "$PORT" --mode live
    docker logs -f --tail 20 "$NAME" ;;
  verify)
    docker run --rm --network host "$IMG" \
      -c -h "$SRC" -p "$PORT" replicate -c -h "$DST" -p "$PORT" --type   # scan + compare
    echo "src keys: $(redis-cli -c -h "$SRC" -p "$PORT" DBSIZE)  dst keys: $(redis-cli -c -h "$DST" -p "$PORT" DBSIZE)  (per node)" ;;
  stop)
    docker stop "$NAME" && docker rm "$NAME"
    echo "Now repoint DNS to Azure, watch app logs, stop AWS nodes after ~1h." ;;
esac
