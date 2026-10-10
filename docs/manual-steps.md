# Manual steps per phase (sanitized)

## 1. Network and access

1. Create VNets/subnets per environment (stage, prod-apps, cloud-management, and later transcoding).
2. Azure Virtual Network Gateway ↔ AWS VPN, with **separate tunnels for stage and prod**. Verify by pinging AWS private IPs from Azure.
3. VPN server (Pritunl) in the management resource group for engineers.
4. Check the regional vCPU quota early. Mine ran out (64/65) while creating Redis VMs. A quota request to 200 was auto-approved.

## 2. Internal DNS during coexistence

1. Create the same private zones (e.g. `<zone>.internal`, `<zone>.private`) as **Azure Private DNS zones** and link them to every VNet.
2. Add an **Azure DNS Private Resolver** with an outbound endpoint and a forwarding ruleset sending AWS-only names to Route53 (inbound resolver in AWS).
3. As each component moves, update its record in the Azure zone.
4. When nothing depends on AWS any more, **disable the forwarding ruleset**, then remove the resolver (it bills per hour).

## 3. Registry, cluster, CI/CD

1. ACR per environment. Mirror base images.
2. AKS + Karpenter NodePools + Istio. Recreate Gateways/VirtualServices.
3. Create an Azure branch per repo. Point Jenkins at ACR + AKS.
4. Standardise deployment names (shared sheet reviewed with the dev team).
5. For gRPC over TLS: a **separate `istio-ingressgateway-grpc` LoadBalancer Service**, with TLS terminated in Envoy from a k8s secret (see `manifests/`).
6. Cross-cloud AWS access from pods (S3 etc.): IAM roles don't work in Azure, so use scoped IAM access keys stored as secrets.

## 4. Stage cutover

1. Deploy all services. Collect failures and hand build errors (TypeScript types, Python dependencies) to the dev team.
2. Test gRPC with a temporary hostname pointed at Azure.
3. Switch all stage domains to Azure, then redeploy from Jenkins.
4. Shut down AWS stage once testing is signed off, then delete it.

## 5. Redis (per cluster)

```bash
# on each AWS source (for RIOT live mode)
redis-cli -h <src> CONFIG SET notify-keyspace-events KEA

# initial copy + live sync (cluster mode)
docker run --rm --network host fieldengineering/riot \
  -c -h <src-node> -p 6379 replicate -c -h <dst-node> -p 6379 --mode live

# verification run (scan + compare)
docker run --rm --network host fieldengineering/riot \
  -c -h <src-node> -p 6379 replicate -c -h <dst-node> -p 6379 --type
```
Cutover: stop the sync, then **repoint the DNS record** to the Azure IPs and watch app logs. Stop the AWS nodes ~1h later, and terminate them after a few days.

## 6. Kafka

1. Size from the source: AWS brokers had 1 TB data disks at ~4% used, so Azure got 100 GB data + 30 GB OS per broker.
2. Build a 3-broker KRaft cluster. Add monitoring (Grafana) and a UI (AKHQ).
3. Recreate topics with the same partitions/replication/configs (`scripts/kafka-recreate-topics.sh`).
4. Repoint `kafka{1,2,3}.<zone>.internal` to the new brokers. The exact order of switching producers and consumers is [UNKNOWN] in my notes.
5. Stop the AWS brokers once their consumer lag is drained, then terminate them.

## 7. Cassandra (same cluster, new nodes)

1. Back up / snapshot the AWS nodes.
2. Create 3 VMs (ARM, no public IP), spread across subnets/zones. Same Cassandra version and `cluster_name`, seeds = existing nodes.
3. Start **one node at a time** and wait for `UN` in `nodetool status` (`nodetool netstats` shows bootstrap streaming).
4. Point clients/DNS seeds at the Azure nodes.
5. Remove the AWS nodes one at a time (`nodetool decommission` on each, or `removenode` if it's already gone). Which one I used is [UNKNOWN].

## 8. Prod app cutover

1. Run all prod services on AKS against the existing backends.
2. Switch in batches by DNS. Websocket services last: new connections land on Azure while old ones drain on AWS.
3. Check **idle timeouts** for long-lived connections. My notes record a 30s default idle timeout on the Azure gateway path.
4. Scale EKS workers to 0 once no traffic is left. Keep the control plane briefly for rollback.

## 9. Finish

- Private DNS fully in Azure. Forwarding ruleset disabled. VPN tunnels removed.
- VM backups enabled. Grafana alerting for VMs and AKS. Uptime checks updated for every Azure virtual service.
- AWS cleanup (stage, EC2, snapshots, AMIs, unused ECR repos).
