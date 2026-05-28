# BlockFrost Icebreaker

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](../deployment/01-cardano-node-installation.md)
2. [Mithril Node installation](../deployment/02-mithril-installation.md)
3. [Cardano DBSync installation](../deployment/03-cardano-dbsync-installation.md)
4. [Midnight Node installation](../deployment/04-midnight-installation.md)
5. [Midnight DBSync installation](../deployment/05-midnight-dbsync-installation.md)
6. [Local Docker](../deployment/06-docker-installation.md)

**Registration**
1. [Registering a Stake Pool](01-registering-stake-pool.md)
2. [Managing a Stake Pool](02-managing-stake-pool.md)
3. [Registering a DRep](03-registering-drep.md)
4. [Registering a Constitutional Committee member](04-registering-constitutional-committee.md)
5. **BlockFrost Icebreaker**
6. [Registering a Midnight Validator](06-registering-midnight-validator.md)

---

Installed on a Relay connected to your block producing SPOs topology.

```shell
# RELAY: Download BlockFrost and init
scripts/node/icebreaker.sh download

# RELAY: Install BlockFrost service and start
scripts/node/icebreaker.sh install

# Check installed version
blockfrost-platform --version
```

When running, you can monitor the processes:

```shell
scripts/node/icebreaker.sh watch
scripts/node/icebreaker.sh status
```

You can review icebreaker status using the BlockFrost UI:

- [https://blockfrost.grafana.net/public-dashboards/8d618eda298d472a996ca3473ab36177](https://blockfrost.grafana.net/public-dashboards/8d618eda298d472a996ca3473ab36177)
- [https://platform.blockfrost.io/verification](https://platform.blockfrost.io/verification)

---

