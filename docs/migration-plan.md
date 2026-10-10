# Migration plan

## Scope

Production and staging accounts: EKS workloads (~50 microservices, HTTP and gRPC), self-managed Redis clusters, Kafka (3 brokers), Cassandra (3 nodes), Elasticsearch/APM, MySQL + ProxySQL, MongoDB Atlas, internal Route53 private zones, CI/CD (Jenkins), monitoring. The transcoding/live-streaming cluster was a later, separate phase.

Out of scope: an analytics account (EMR + Airflow stayed in AWS, reached through a tunnel). We decided not to add a directory service (Active Directory), because it wasn't needed for a small team.

## Order

1. **Foundation**: VNets per environment, site-to-site VPN to AWS (one tunnel per env), a VPN server for engineers, Azure Private DNS + DNS Private Resolver forwarding to Route53, ACR, AKS (Karpenter, Istio), Jenkins pipelines.
2. **Stage first**: deploy all services, have the dev team fix build/runtime issues, test gRPC, switch all stage domains, shut down AWS stage.
3. **Prod apps on AKS** running against the AWS backends over the VPN.
4. **Prod data layer**, one store at a time:
   - Redis: RIOT initial copy + live sync, then DNS cutover
   - Kafka: fresh cluster, recreate topics, repoint DNS
   - Cassandra: add Azure nodes to the same cluster, then remove AWS nodes
   - MySQL/ProxySQL: other teams. MongoDB Atlas: provider change by the client team
5. **Prod app cutover** in batches by DNS. Websocket and auth-type services went last.
6. **DNS independence**: move private zones fully to Azure and disable forwarding to AWS.
7. **Cleanup** in AWS: delete stage, terminate backend EC2, delete snapshots/AMIs, scale EKS workers to 0.
8. **Transcoding** stack later, with an end-to-end OBS → ingest → transcode → HLS test before switching.

## Why each data-store method

| Store | Why |
|---|---|
| Redis | Small data set, and no native cross-cloud replication for these clusters. RIOT live mode keeps the target close to real-time, so cutover is just a DNS change |
| Kafka | Messages are short-lived. A fresh cluster avoids MirrorMaker complexity. Disks were ~4% used, so they were right-sized (1 TB → 100 GB per broker) |
| Cassandra | Native streaming: new nodes bootstrap from existing replicas, so there's no export/import and no downtime |

## Risks we tracked

- Cross-cloud latency while apps and backends were split across the VPN
- Regional vCPU quota on the Azure subscription
- gRPC over TLS through Azure load balancers
- Internal DNS names resolving differently on each side during coexistence
- Cross-account access: AWS IAM roles don't exist in Azure
