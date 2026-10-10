# After the cutover

Cleanup and optimisation done in the weeks after the migration. Several of these are separate case-study repos.

| Area | What | Result |
|---|---|---|
| AWS cleanup | Stage deleted, backend EC2 terminated, snapshots/AMIs removed, unused ECR repos deleted, EKS workers at 0 | Done |
| Azure cleanup | Idle DNS resolver, stage AWS tunnels, unused NAT gateways removed | Done |
| Storage | 7 stale DB backup disks (~5.6 TB) removed with no downtime | `azure-stale-backup-disk-cleanup` |
| NAT egress | MongoDB Atlas traffic leaking via NAT moved to private peering | `nat-egress-cost-mongodb-atlas-private-peering` |
| Metrics traffic | Prometheus remote_write cut ~460 → ~78 GB/day | `prometheus-remote-write-reduction` |
| AKS right-sizing | Requests from 7-day usage + a nightly scale-down. App nodes 28 → 17 | Follow-up error/latency check [UNKNOWN] |
| Monitoring | Port-level probes for every VM service + a fixed alert rule | Done |
| TLS | Wildcard cert runbook extended to every Azure TLS path | `letsencrypt-wildcard-renewal-multi-tls-paths` |
