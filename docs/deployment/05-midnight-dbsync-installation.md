# Midnight DBSync installation

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. [Mithril Node installation](02-mithril-installation.md)
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
4. [Midnight Node installation](04-midnight-installation.md)
5. **Midnight DBSync installation**
6. [Local Docker](06-docker-installation.md)

**Registration**
1. [Registering a Stake Pool](../registration/01-registering-stake-pool.md)
2. [Managing a Stake Pool](../registration/02-managing-stake-pool.md)
3. [Registering a DRep](../registration/03-registering-drep.md)
4. [Registering a Constitutional Committee member](../registration/04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](../registration/05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](../registration/06-registering-midnight-validator.md)

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

