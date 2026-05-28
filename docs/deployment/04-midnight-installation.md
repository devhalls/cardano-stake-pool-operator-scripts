# Midnight Node installation

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. [Mithril Node installation](02-mithril-installation.md)
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
4. **Midnight Node installation**
5. [Midnight DBSync installation](05-midnight-dbsync-installation.md)
6. [Local Docker](06-docker-installation.md)

**Registration**
1. [Registering a Stake Pool](../registration/01-registering-stake-pool.md)
2. [Managing a Stake Pool](../registration/02-managing-stake-pool.md)
3. [Registering a DRep](../registration/03-registering-drep.md)
4. [Registering a Constitutional Committee member](../registration/04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](../registration/05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](../registration/06-registering-midnight-validator.md)

---

Operating a midnight node requires operating additional partner chain services. For midnight testnet this repository
contains a docker deployment separate from other stake pool node services.

Install docker and docker compose if needed:

- [Install Docker Engine](https://docs.docker.com/engine/install/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)

```shell
# Enter the directory
cd midnight

# Start / restart containers
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml restart

# Monitor the logs
docker logs -f --tail 100 cardano-ogmios
docker logs -f --tail 100 cardano-db-sync
docker logs -f --tail 100 db-sync-postgres
docker logs -f --tail 100 cardano-node
docker logs -f --tail 100 midnight-node

# Query the Ogmios service health
curl -s localhost:1337/health | jq '.'

# Query the sidechain status
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "sidechain_getStatus",
    "params": [],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Query your node peers
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "system_peers",
    "params": [],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Query the committee
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "sidechain_getEpochCommittee",
    "params": [245148],
    "id": 1
}' http://127.0.0.1:9944 | jq
```

