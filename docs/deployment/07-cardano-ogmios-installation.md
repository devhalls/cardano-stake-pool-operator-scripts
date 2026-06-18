# Cardano Ogmios installation

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. [Mithril Node installation](02-mithril-installation.md)
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
4. [Midnight Node installation](04-midnight-installation.md)
5. [Midnight DBSync installation](05-midnight-dbsync-installation.md)
6. [Local Docker](06-docker-installation.md)
7. **Cardano Ogmios installation**

**Registration**
1. [Registering a Stake Pool](../registration/01-registering-stake-pool.md)
2. [Managing a Stake Pool](../registration/02-managing-stake-pool.md)
3. [Registering a DRep](../registration/03-registering-drep.md)
4. [Registering a Constitutional Committee member](../registration/04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](../registration/05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](../registration/06-registering-midnight-validator.md)

---

Ogmios is a lightweight HTTP/WebSocket bridge to a local `cardano-node`. It is optional on native installs and included in the local Docker stack by default.

Binaries and Docker images are published by [CardanoSolutions/ogmios](https://github.com/CardanoSolutions/ogmios/releases), not IntersectMBO. Pin `OGMIOS_VERSION` in your env file; the latest release may list a lower tested `cardano-node` version than `NODE_VERSION` — verify with the health endpoint after install.

### Native install

Requires a synced warm node (relay or producer) with the socket at `$NETWORK_SOCKET_PATH`.

```shell
scripts/ogmios.sh download
scripts/ogmios.sh install
scripts/ogmios.sh start
scripts/ogmios.sh watch
```

Check status in the stack overview:

```shell
scripts/node.sh status
```

### Ogmios update

Edit `OGMIOS_VERSION` in your env file, then:

```shell
scripts/ogmios.sh update
```

### Docker

Ogmios starts with the default Docker stack:

```shell
./docker/run.sh up -d --build
curl -s "localhost:${OGMIOS_PORT:-1337}/health" | jq '.'
docker logs -f --tail 100 ogmios
```

See [Local Docker](06-docker-installation.md) for container management.

---
