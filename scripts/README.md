# Scripts and their manual steps

Each script below has a **manual** version: the same steps run by hand, one command at a time. Use the manual steps the first time you run a migration so you can see each result before moving on.

- Lines marked ✅ are the commands I actually ran during the migration (sanitized).
- Everything else is a reconstruction of standard practice. The scripts themselves are **untested reconstructions**.

| Script | Manual section |
|---|---|
| [redis-riot-sync.sh](redis-riot-sync.sh) | [1. Redis live sync and cutover](#1-redis-live-sync-and-cutover) |
| [kafka-recreate-topics.sh](kafka-recreate-topics.sh) | [2. Kafka: fresh cluster, recreate topics](#2-kafka-fresh-cluster-recreate-topics) |
| [cassandra-add-azure-nodes.sh](cassandra-add-azure-nodes.sh) | [3. Cassandra: add Azure nodes, remove AWS nodes](#3-cassandra-add-azure-nodes-remove-aws-nodes) |
| [dns-cutover-check.sh](dns-cutover-check.sh) | [4. DNS cutover check](#4-dns-cutover-check) |

---

## 1. Redis live sync and cutover

Run from a host that can reach both sides (over the VPN). Repeat for each Redis cluster.

**1.1 Check source and target**
```bash
redis-cli -c -h <aws-node> -p 6379 INFO server | grep redis_version
redis-cli -c -h <azure-node> -p 6379 INFO server | grep redis_version     # same version
redis-cli -c -h <aws-node> -p 6379 CLUSTER INFO | grep cluster_state       # ok on both
redis-cli -c -h <aws-node> -p 6379 INFO memory | grep used_memory_human     # size the target
```

**1.2 Enable keyspace notifications on every source master** (RIOT live mode needs them) ✅
```bash
redis-cli -h <aws-master-N> -p 6379 CONFIG SET notify-keyspace-events KEA
redis-cli -h <aws-master-N> -p 6379 CONFIG GET notify-keyspace-events
```

**1.3 Start initial copy + live sync** ✅
```bash
docker run -d --name riot-<cluster> --network host fieldengineering/riot \
  -c -h <aws-node> -p 6379 replicate -c -h <azure-node> -p 6379 --mode live
docker logs -f riot-<cluster>          # wait for the scan to reach 100%, then it keeps listening
```

**1.4 Verify** ✅ (one cluster's run: `ok: 362,385` of 362,385)
```bash
docker run --rm --network host fieldengineering/riot \
  -c -h <aws-node> -p 6379 replicate -c -h <azure-node> -p 6379 --type
# compare key counts per master on both sides
redis-cli -c -h <aws-master-N>   -p 6379 DBSIZE
redis-cli -c -h <azure-master-N> -p 6379 DBSIZE
```

**1.5 Cutover**
1. Update the internal DNS record(s) for the cluster to the Azure node IPs.
2. Watch app logs for Redis errors (`CLUSTERDOWN`, `MOVED` loops, timeouts).
3. Check that clients are connecting to the Azure nodes:
   ```bash
   redis-cli -h <azure-node> -p 6379 INFO clients | grep connected_clients
   redis-cli -h <aws-node>   -p 6379 INFO clients | grep connected_clients   # should drop
   ```
4. Stop RIOT: `docker stop riot-<cluster> && docker rm riot-<cluster>`.
5. Stop the AWS nodes ~1 hour later ✅. Terminate them and their volumes after a few days.

---

## 2. Kafka: fresh cluster, recreate topics

**2.1 Size the new cluster from the old one** ✅ (old data disks were 1 TB at ~4% used → 100 GB new)
```bash
df -h /data        # on each old broker
```

**2.2 List topics and their settings on the old cluster**
```bash
kafka-topics.sh --bootstrap-server <old-broker>:9092 --list | grep -v '^__'
kafka-topics.sh --bootstrap-server <old-broker>:9092 --describe --topic <topic> | head -1
#   -> PartitionCount: N   ReplicationFactor: R
kafka-configs.sh --bootstrap-server <old-broker>:9092 --entity-type topics --entity-name <topic> --describe
#   -> note only non-default configs (retention.ms, cleanup.policy, ...)
```
Put them in a sheet: topic, partitions, RF, configs.

**2.3 Create each topic on the new cluster**
```bash
kafka-topics.sh --bootstrap-server <new-broker>:9092 --create --if-not-exists \
  --topic <topic> --partitions <N> --replication-factor <R> \
  --config retention.ms=<value>            # repeat --config per non-default setting
```

**2.4 Compare**
```bash
diff <(kafka-topics.sh --bootstrap-server <old-broker>:9092 --list | sort) \
     <(kafka-topics.sh --bootstrap-server <new-broker>:9092 --list | sort)
```

**2.5 Cutover**
1. Make sure old consumer groups have no lag:
   ```bash
   kafka-consumer-groups.sh --bootstrap-server <old-broker>:9092 --describe --all-groups | awk '$6>0'
   ```
2. Repoint `kafka1/2/3.<zone>.internal` to the new brokers and restart producers and consumers.
3. Check new groups are consuming (`--describe --all-groups` on the new cluster) and look at the cluster UI/Grafana.
4. Stop the old brokers ✅, then terminate them.

---

## 3. Cassandra: add Azure nodes, remove AWS nodes

**3.1 Before**
```bash
nodetool status                 # all UN
nodetool describecluster        # one schema version
nodetool snapshot -t pre-migration     # backup ✅ (backup taken before starting)
```

**3.2 Prepare each new Azure VM** (same Cassandra version). `cassandra.yaml`:
```yaml
cluster_name: '<same as existing>'
seed_provider: [{class_name: org.apache.cassandra.locator.SimpleSeedProvider, parameters: [{seeds: "<aws-seed-1>,<aws-seed-2>"}]}]
listen_address: <this-vm-private-ip>
rpc_address: <this-vm-private-ip>
endpoint_snitch: <same snitch as existing>
auto_bootstrap: true
```
Make sure ports 7000 and 9042 are open both ways over the VPN.

**3.3 Start ONE node and watch it join** ✅
```bash
sudo systemctl start cassandra
nodetool status          # new node shows UJ (joining)
nodetool netstats        # "Mode: JOINING ... Receiving N files"
```
Wait for `UN`, then start the next node. Repeat for all 3 ✅ (all three joined, all UN).

**3.4 Point clients at the Azure nodes**: update the seed/contact-point DNS records and restart the apps.

**3.5 Remove the AWS nodes one at a time** (the method I used is [UNKNOWN])
```bash
# on the AWS node being removed (preferred: streams its data away cleanly)
nodetool decommission
nodetool netstats        # wait until it finishes
# from any live node, if an AWS node is already down:
nodetool removenode <host-id>
```
Check `nodetool status` after each removal. Once only Azure nodes remain, update the seeds in `cassandra.yaml` to Azure IPs and do a rolling restart.

**3.6 After**
```bash
nodetool status; nodetool describecluster
nodetool cleanup         # on each remaining node, one at a time
```

---

## 4. DNS cutover check

Run from **both** an AKS pod and a VM, because they can resolve differently during coexistence.

**4.1 Resolve each internal name**
```bash
getent ahostsv4 <host>.<zone>.internal      # or: dig +short <host>.<zone>.internal
```
Any answer in the old cloud's CIDR is not cut over yet.

**4.2 From inside the cluster**
```bash
kubectl run dnscheck --rm -it --image=busybox:1.36 --restart=Never -- nslookup <host>.<zone>.internal
```

**4.3 Fix a record in Azure Private DNS**
```bash
az network private-dns record-set a list -g <rg> -z <zone>.internal -o table
az network private-dns record-set a remove-record -g <rg> -z <zone>.internal -n <host> -a <old-ip>
az network private-dns record-set a add-record    -g <rg> -z <zone>.internal -n <host> -a <new-ip>
```

**4.4 When nothing points to the old cloud any more**: disable the DNS forwarding ruleset to the old cloud ✅, then remove the resolver.
