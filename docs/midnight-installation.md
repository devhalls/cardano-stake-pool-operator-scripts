# Midnight Node installation

[README](../README.md)

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

