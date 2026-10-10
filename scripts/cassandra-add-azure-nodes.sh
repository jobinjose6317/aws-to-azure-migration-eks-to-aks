#!/usr/bin/env bash
# UNTESTED RECONSTRUCTION. Not run as written.
# Helpers for moving Cassandra by adding new nodes to the same cluster, then removing old ones.
# Run ON a Cassandra node.  Usage: ./cassandra-add-azure-nodes.sh wait-join | remove-self | status
set -euo pipefail

case "${1:?wait-join|remove-self|status}" in
  wait-join)   # run on the NEW node after starting cassandra (one node at a time)
    until nodetool status | awk -v ip="$(hostname -I | awk '{print $1}')" '$2==ip {print $1}' | grep -q '^UN$'; do
      nodetool netstats | grep -E 'Mode|Receiving' | head -5; sleep 30
    done
    echo "joined (UN). Start the next node." ;;
  remove-self) # run on an OLD node after clients point to new nodes
    nodetool status
    read -rp "Decommission THIS node? (yes/no) " a; [[ $a == yes ]] || exit 1
    nodetool decommission && nodetool netstats | head ;;
  status)
    nodetool status; nodetool describecluster | head -20 ;;
esac
