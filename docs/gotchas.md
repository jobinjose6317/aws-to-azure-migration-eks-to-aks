# Gotchas

1. **gRPC over TLS through the existing Azure ingress path didn't work.** I added a separate `type: LoadBalancer` Istio ingress gateway for gRPC, with TLS terminated by Envoy (SDS secret). HTTP/REST kept using Application Gateway.
2. **Idle timeouts differ.** My notes record a 30s default idle timeout on the Azure gateway path, which matters for the websocket service. Check timeouts for long-lived connections before switching.
3. **Regional vCPU quota.** Central India hit 64/65 vCPUs mid-migration. Request quota before building data-layer VMs.
4. **IAM roles don't cross clouds.** Pods in AKS that still needed S3 used scoped IAM access keys stored as Kubernetes secrets.
5. **Keyspace notifications for RIOT live mode.** They must be enabled on the source Redis, or live sync silently stops after the initial copy.
6. **Two DNS worlds.** During coexistence, Azure resolved internal names through a resolver forwarding to Route53. Remember to disable the forwarding and remove the resolver afterwards, because it bills per hour even when idle.
7. **Cloud-provider change on a managed DB breaks old peering.** After MongoDB Atlas moved from AWS to Azure, the AWS VPC peering stopped working. Servers in private AWS subnets couldn't reach it. Public-subnet services worked once their NAT IP was allow-listed. (A later Azure-side peering/region issue is a separate case study: NAT egress cost.)
8. **ARM availability.** I first assumed no ARM in the region, but Azure ARM sizes (Dpsv6) were available and used for Cassandra. Databases that needed x86 stayed on AMD/Intel.
9. **Resizing VMs can enable Accelerated Networking**, which broke VPN-connected NICs. Disable it (requires deallocation).
10. **Azure Backup minimum retention is 7 days.** A request for 3-day retention wasn't possible.
11. **Inventory everything, not just what's in Kubernetes.** One AWS-side setup outside the clusters was missed and found two months later.
12. **Keep the old control plane briefly.** EKS stayed with 0 worker nodes, so rollback was possible without paying for compute.
