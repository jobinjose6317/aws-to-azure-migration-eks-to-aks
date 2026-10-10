# Timeline (2026)

| Date | Milestone |
|---|---|
| 24 Apr | Migration plan shared (EKS, Redis, Cassandra, MySQL, ProxySQL, Kafka, MongoDB Atlas) |
| early May | Start delayed by another priority project (a live-video service migration), then kicked off |
| 15 May | Site-to-site VPN (separate stage/prod tunnels) + VPN server done |
| 18 May | Internal DNS done |
| 19–20 May | ACR done. AKS + CI/CD started |
| 26 May | Deployment naming standardised with the dev team |
| 2 Jun | Stage: 47 up / 6 waiting on code fixes |
| 9–11 Jun | Stage domains switched to Azure. All stage apps on Azure except one |
| 11 Jun | Separate L4 load balancer for gRPC over TLS |
| 22 Jun | Prod: 46 services healthy on AKS. Redis VMs built, quota raised to 200 vCPU, RIOT initial sync + live mode |
| 23 Jun | All prod Redis clusters switched by DNS. AWS Redis stopped |
| 25 Jun – 2 Jul | Prod services switched in batches. 5 left on AWS by 2 Jul |
| 7 Jul | Fresh Kafka cluster live (monitoring + UI). AWS brokers stopped |
| 8 Jul | Cassandra: 3 Azure nodes joined (all UN). Private DNS zones moved to Azure |
| 9 Jul | Last services (websocket, partner API) switched. **Migration declared complete**: AWS backends terminated, stage deleted |
| 10 Jul | Last tools moved. EKS kept with 0 worker nodes |
| Jul | AWS cost cleanup (idle resolver, stage tunnels, ECR) |
| Aug – 2 Sep | Transcoding stack built on Azure, tested end to end, switched |
| mid Sep | A missed AWS-only setup found and rebuilt in Azure |
| Sep – Oct | Post-migration optimisation (see post-migration.md) |
