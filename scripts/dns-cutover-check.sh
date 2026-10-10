#!/usr/bin/env bash
# UNTESTED RECONSTRUCTION. Not run as written.
# For each internal hostname, shows what it resolves to from where you run it and flags
# names that still point into the old cloud's CIDR. Run it from an AKS pod and from a VM.
# Usage: OLD_CIDR_PREFIX=10.0. ./dns-cutover-check.sh hosts.txt
set -uo pipefail
FILE="${1:?file with one hostname per line}"; OLD="${OLD_CIDR_PREFIX:?e.g. 10.0.}"
while read -r h; do
  [[ -z "$h" || "$h" == \#* ]] && continue
  ips=$(getent ahostsv4 "$h" | awk '{print $1}' | sort -u | paste -sd' ' -)
  flag=$([[ " $ips" == *" $OLD"* ]] && echo "STILL-OLD" || echo "ok")
  printf '%-55s %-35s %s\n' "$h" "${ips:-NXDOMAIN}" "$flag"
done < "$FILE"
