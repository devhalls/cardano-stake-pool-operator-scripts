# Cardano DBSync installation

[README](../README.md)

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

