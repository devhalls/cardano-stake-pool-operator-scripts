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

This repository pins [cardano-db-sync **13.7.2.1**](https://github.com/IntersectMBO/cardano-db-sync/releases/tag/13.7.2.1) (`DB_SYNC_VERSION` in `env`). It matches **cardano-node 11.x** (see `NODE_VERSION` in `env.example`).

| Variable | Example | Notes |
| -------- | ------- | ----- |
| `DB_SYNC_VERSION` | `13.7.2.1` | Release tag; binaries from [`DB_SYNC_REMOTE`](https://github.com/IntersectMBO/cardano-db-sync/releases) |
| `POSTGRES_SNAPSHOT` | `…/13.7/db-sync-snapshot-…` | Mainnet bootstrap only; pick a current file from the [13.7 snapshot index](https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#13.7/) or [13.6 index](https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#13.6/) |
| `DB_SYNC_ROLLBACK_SLOT` | _(empty)_ | Optional; passed as `--rollback-to-slot` when set |

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

### Bootstrap from an IOG snapshot (mainnet)

For a new mainnet database without syncing from genesis, set `POSTGRES_SNAPSHOT` in `env` to a tarball URL from the
[13.7](https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#13.7/) or
[13.6](https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html#13.6/) snapshot listing (both are compatible
with 13.7.2.1), then:

```shell
scripts/dbsync.sh snapshot
scripts/dbsync.sh process
scripts/dbsync.sh import
```

`import` runs `pg_restore` with verbose logging (table-by-table). In a **second SSH session**, poll disk growth while import continues:

```shell
scripts/dbsync.sh watch-import
# or once: scripts/dbsync.sh import-status
```

IOG mainnet snapshots are ~75 GiB compressed and may take 20–40+ minutes. If the download fails with `Connection reset by peer`, run `snapshot` again—the script resumes the partial file (`wget -c` or `curl -C -`). Use `tmux` or `screen` so an SSH disconnect does not stop the transfer.

After import, run `download` and `install` if you have not already, then start the service.

### DBSync update

When you would like to update db-sync, edit `DB_SYNC_VERSION` in your env file and run the update script. Schema
migrations ship under `configs/schema/` and are copied to `$DB_SYNC_PATH/schema` on `install`.

**Upgrading to 13.7.2.1** (from [release notes](https://github.com/IntersectMBO/cardano-db-sync/releases/tag/13.7.2.1)):

- From **13.7.1.x**: startup runs `migration-2-0049` (epoch table → view; several minutes on mainnet) and `migration-2-0050` (`pool_relay.port` repair).
- From **13.7.0.x**: also runs `migration-2-0048` (epoch fix from 13.7.1.0) before those migrations.
- Queries on the `epoch` view may be ~500ms slower on mainnet; use `epoch_finalized` when you do not need the in-progress epoch.

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

### Migrating to another device

To move a synced instance to a new machine without re-importing an IOG snapshot, see
[Cardano DBSync migration](08-cardano-dbsync-migration.md).

---

