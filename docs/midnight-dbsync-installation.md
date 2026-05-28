# Midnight DBSync installation

[README](../README.md)

---

For midnight DBSync testnet we extend our existing docker compose
with [compose-indexer.yml](midnight/compose-indexer.yml).
This contains the additional services required to operate a Midnights archive node and Midnight DBSync, while keeping
our
validator node separate.

The only dependency with the other midnight docker services is Cardano DBSync postgres, which is necessary for an
archive node. 

```shell
# Enter the directory
cd midnight

# Make the .env and set the variables
cp .env.example .env
nano .env

# Start / restart containers
docker compose -f ./compose-partner-chains.yml up -d
docker compose -f ./compose-partner-chains.yml restart
```

You can then monitor the docker containers:

```shell
docker logs -f midnight-indexer-node
docker logs -f midnight-indexer-chain
docker logs -f midnight-indexer-wallet
docker logs -f midnight-indexer-nats
docker logs -f midnight-indexer-postgres
docker logs -f midnight-indexer-api
```

