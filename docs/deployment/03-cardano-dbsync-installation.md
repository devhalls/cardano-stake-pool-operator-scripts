# Cardano DBSync installation

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. [Mithril Node installation](02-mithril-installation.md)
3. **Cardano DBSync installation**
4. [Midnight Node installation](04-midnight-installation.md)
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

DBSync runs alongside a cardano node and manages a postgres database populated with historical blockchain data. To
operate a DBSync instance, your node must first be fully synced.

With a synced Cardano node, run the setup to install postgres, create the database and create users
for `$POSTGRES_USER` and `$NODE_USER`.

```shell
scripts/dbsync.sh dependencies
scripts/dbsync.sh create
```

Next, download the dbsync binaries, then install and run the service. This will start dbsync and run the migrations for
a new installation.

```shell
scripts/dbsync.sh download
scripts/dbsync.sh install
```

### DBSync update

When you would like to update db-sync, edit `DB_SYNC_VERSION` in your env file and run the update script.

```shell
nano env
scripts/dbsync.sh update
```

When running, you can review the status and progress with the commands below, to see a full list of commands to manage
the instance review the help info for `scripts/dbsync.sh help`,

```shell
scripts/dbsync.sh watch
scripts/dbsync.sh status
```

---

