# Registering a Midnight Validator

[README](../README.md)

---

If you're running a block producing Stake Pool on the Preview network, you can opt to run as a Midnight validator.
When you have the midnight docker container installed and running (see [Midnight Node installation](midnight-installation.md)), you can run the
installation wizards (defined here in
the [midnight documentation](https://docs.midnight.network/validate/run-a-validator/step-3)):

```
# View wizard used for configurations once all partner services are up and running
./midnight-node.sh wizards --help

# Then you can start and restart containers
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml restart

# If you need to edit postgres container files, e.g:
docker exec -it db-sync-postgres bash -c "echo 'host    all    all    172.22.0.0/16    scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
docker exec -it db-sync-postgres bash -c "echo 'host    all    all    172.2=5.0.0/16    scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf" 
```

### Validate your Midnight node keys

Once you have completed the registration steps and all services are operational, you can validate your node operations
and registration by querying the local rpc.

Query the services and search the results to ensure you are present, and the 'isValid' parameter is true.

```shell
# EPOCH_NUMBER = preview network registration epoch
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "sidechain_getAriadneParameters",
    "params": [<EPOCH_NUMBER>],
    "id": 1
}' http://127.0.0.1:9944 | jq
```

To confirm your Midnight Validator keys are configured correctly, query the author_hasKey for each key:

```shell
# Validate the sidechain_pub_key
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "author_hasKey",
    "params": ["<YOUR_KEY>", "crch"],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Validate the aura_pub_key
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "author_hasKey",
    "params": ["<YOUR_KEY>", "aura"],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Validate the grandpa_pub_key
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "author_hasKey",
    "params": ["<YOUR_KEY>", "gran"],
    "id": 1
}' http://127.0.0.1:9944 | jq
```

### Monitoring Midnight node

Once running, you can monitor the midnight node using the docker logs and the community tool ./LiveView.sh linked above.

```
# Mannually enter the node shell
docker exec -it <CONTAINER_ID> bash

# Watch logs for each midnight service
docker logs -f --tail 100 cardano-ogmios
docker logs -f --tail 100 cardano-db-sync
docker logs -f --tail 100 db-sync-postgres
docker logs -f --tail 100 cardano-node
docker logs -f --tail 100 midnight-node

# LiveView tool is our recommended way to monitor your Midnight producer
./LiveView.sh
```

---

