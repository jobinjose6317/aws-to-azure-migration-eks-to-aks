#!/usr/bin/env bash
# UNTESTED RECONSTRUCTION. Not run as written.
# Copies topic definitions (partitions, RF, non-default configs) from the old cluster to a fresh one.
# Usage: OLD=<old-broker:9092> NEW=<new-broker:9092> ./kafka-recreate-topics.sh [--dry-run]
set -euo pipefail
: "${OLD:?}" "${NEW:?}"; DRY="${1:-}"
KT="${KAFKA_HOME:-/opt/kafka}/bin"

for t in $("$KT/kafka-topics.sh" --bootstrap-server "$OLD" --list | grep -v '^__'); do
  desc=$("$KT/kafka-topics.sh" --bootstrap-server "$OLD" --describe --topic "$t" | head -1)
  parts=$(sed -n 's/.*PartitionCount: *\([0-9]*\).*/\1/p' <<<"$desc")
  rf=$(sed -n 's/.*ReplicationFactor: *\([0-9]*\).*/\1/p' <<<"$desc")
  cfg=$("$KT/kafka-configs.sh" --bootstrap-server "$OLD" --entity-type topics --entity-name "$t" --describe \
        | sed -n 's/^ *\([a-z.]*\)=\([^ ]*\) sensitive=false.*DYNAMIC_TOPIC_CONFIG.*/\1=\2/p' | paste -sd, -)
  echo "$t partitions=$parts rf=$rf ${cfg:+config=$cfg}"
  [[ "$DRY" == "--dry-run" ]] && continue
  "$KT/kafka-topics.sh" --bootstrap-server "$NEW" --create --if-not-exists --topic "$t" \
    --partitions "$parts" --replication-factor "$rf" ${cfg:+$(tr ',' '\n' <<<"$cfg" | sed 's/^/--config /' | tr '\n' ' ')}
done
