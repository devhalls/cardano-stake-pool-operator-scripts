# Cardano DBSync migration to another device

[Full docs index](../README.md) · [DBSync installation](03-cardano-dbsync-installation.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. [Mithril Node installation](02-mithril-installation.md)
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
4. [Midnight Node installation](04-midnight-installation.md)
5. [Midnight DBSync installation](05-midnight-dbsync-installation.md)
6. [Local Docker](06-docker-installation.md)
7. [Cardano Ogmios installation](07-cardano-ogmios-installation.md)
8. **Cardano DBSync migration**

---

Move a fully synced db-sync instance to another machine on the same LAN **without re-importing an IOG snapshot or replaying the chain from genesis**. You copy the PostgreSQL database and db-sync ledger state, install db-sync on the new host, then point your API (or other consumers) at the new database.

This guide assumes:

- **Source:** mainnet db-sync already running via these scripts (`scripts/dbsync.sh`).
- **Target:** mainnet relay already installed, synced, and running (`scripts/node.sh status`).
- Both hosts can reach each other over the LAN (SSH/`rsync`).

## What gets copied

| Component | Location | Required |
|-----------|----------|----------|
| PostgreSQL database | `$POSTGRES_DB` (default `cexplorer_mainnet`) | Yes |
| db-sync ledger state | `$DB_SYNC_PATH/ledger-state/` | Yes |
| db-sync binaries & schema | Installed via `scripts/dbsync.sh download` / `install` on target | Reinstall, do not copy from source |
| Cardano node chain | `$NETWORK_DB_PATH` on target relay | Already present (synced relay) |

The PostgreSQL dump is the bulk of the data (often hundreds of GB on mainnet). The ledger-state directory is small but required so db-sync resumes correctly.

## Prerequisites

1. **Matching db-sync version** on both hosts. On each machine:

   ```shell
   scripts/dbsync.sh current
   ```

   Set the same `DB_SYNC_VERSION` in `env` on the target before `download`. If versions differ, update the source first (`scripts/dbsync.sh update`) or match the exported version on the target.

2. **Matching network** — `NODE_NETWORK=mainnet` on both hosts.

3. **Same database name** (recommended) — default `cexplorer_$NODE_NETWORK`. The export writes `migration/manifest.txt` with version, block height, and database name for verification on restore.

4. **Disk space** on the target for the dump **and** the restored database (roughly 2× DB size during restore, then delete the dump).

5. **Downtime window** — stop db-sync on the source before export so the dump is consistent. Your API will be read-only/offline until the target is running.

## Overview

```mermaid
flowchart LR
  A[Source: stop db-sync] --> B[export DB + ledger-state]
  B --> C[rsync migration/ to target]
  C --> D[Target: postgres + restore]
  D --> E[import ledger-state]
  E --> F[install + start db-sync]
  F --> G[Point API at new host]
```

---

## Phase 1 — Source (old device)

Run as `$NODE_USER` from the repo root (where `env` lives).

### 1. Record baseline

```shell
scripts/dbsync.sh current
scripts/dbsync.sh get_block
scripts/node.sh status
```

Note the block number; you will compare after migration.

### 2. Stop db-sync

```shell
scripts/dbsync.sh stop
```

Leave the Cardano node running if other services need it; db-sync must be stopped for a consistent export.

### 3. Export database and ledger state

```shell
scripts/dbsync.sh export
scripts/dbsync.sh export-state
```

This creates:

```
$DB_SYNC_PATH/migration/
├── db/                    # pg_dump directory format
├── ledger-state.tar.gz
└── manifest.txt           # version, block, database name
```

Mainnet exports can take hours depending on disk and CPU.

### 4. Copy migration bundle to the target

Replace `NEW_HOST` and paths with your values. `$DB_SYNC_PATH` defaults to `$NODE_HOME/cardano-db-sync`.

```shell
rsync -avh --progress \
  "$DB_SYNC_PATH/migration/" \
  NEW_USER@NEW_HOST:"$DB_SYNC_PATH/migration/"
```

Use a wired connection if possible. For very large transfers, `rsync` can be resumed if interrupted.

Optional: after verifying the copy on the target, decommission the old db-sync service (keep the data until the target is verified).

---

## Phase 2 — Target (new device)

The relay node should already be synced. Configure `env` for mainnet (`NODE_NETWORK=mainnet`, `NODE_TYPE=relay`, paths, users).

### 1. Align db-sync version

Edit `env` so `DB_SYNC_VERSION` matches the source (`migration/manifest.txt` on the copied bundle):

```shell
grep DB_SYNC_VERSION "$DB_SYNC_PATH/migration/manifest.txt"
nano env   # set DB_SYNC_VERSION to match
```

### 2. Install PostgreSQL and create an empty database

```shell
scripts/dbsync.sh dependencies
scripts/dbsync.sh create
```

If a previous failed attempt left a database behind:

```shell
scripts/dbsync.sh drop
scripts/dbsync.sh create
```

### 3. Restore the database

```shell
scripts/dbsync.sh restore
```

Uses `$DB_SYNC_PATH/migration/db/` by default. Checks `manifest.txt` for db-sync version mismatch.

Restore time is similar to export (often hours on mainnet).

### 4. Restore ledger state

If you copied `migration/` via `rsync`, the archive is already in place:

```shell
scripts/dbsync.sh import-state
```

Alternatively, sync the directory directly (without the tarball):

```shell
rsync -avh OLD_USER@OLD_HOST:"$DB_SYNC_PATH/ledger-state/" "$DB_SYNC_PATH/ledger-state/"
```

### 5. Install db-sync (binaries, schema, systemd)

```shell
scripts/dbsync.sh download
scripts/dbsync.sh install
```

Do **not** run `create` again after restore. `install` lays down schema files and the systemd unit; the database already contains the synced data.

### 6. Start db-sync and verify

```shell
scripts/dbsync.sh start
scripts/dbsync.sh watch
```

In another terminal:

```shell
scripts/dbsync.sh get_block
scripts/node.sh status
```

Expect:

- `get_block` close to the block recorded in `manifest.txt` (may lag slightly until db-sync catches up).
- db-sync logs showing forward sync, not a full replay from genesis.
- Catch-up usually completes in minutes if the relay stayed synced during migration.

### 7. Free disk space (optional)

After a successful verify:

```shell
rm -rf "$DB_SYNC_PATH/migration/db"
```

Keep `manifest.txt` or note the verified block for your records.

---

## Phase 3 — Point your API at the new device

How you switch depends on what reads `$POSTGRES_DB`:

### API on the same host as db-sync

Update DNS, reverse proxy, or service config so clients hit the **new** machine. No PostgreSQL network exposure required (default: local socket auth via `$DB_SYNC_PATH/pgpass`).

### API on a different host (PostgreSQL over LAN)

1. Configure PostgreSQL on the target to listen on the LAN interface (`postgresql.conf`: `listen_addresses`).
2. Allow the API host in `pg_hba.conf` (prefer SSL + password; restrict by source IP).
3. Open firewall port `$POSTGRES_PORT` (default `5432`) only from the API host.
4. Update the API connection string: host = new device IP/hostname, same `POSTGRES_DB` / user / password as in `env`.

Restart the API and run a read query (e.g. latest epoch, pool list) against the new endpoint.

### BlockFrost / custom indexers

Update the Postgres connection URL or upstream host in that service's config, then restart. No chain resync is required if the database and ledger state were migrated together.

---

## Rollback

If migration fails on the target:

1. `scripts/dbsync.sh stop`
2. `scripts/dbsync.sh drop && scripts/dbsync.sh create`
3. Fix the issue (version mismatch, incomplete `rsync`, etc.) and repeat Phase 2.

The source device remains intact until you delete data there; you can `scripts/dbsync.sh start` on the source to restore service.

## Troubleshooting

| Symptom | Likely cause | Action |
|---------|--------------|--------|
| Version mismatch on restore | `DB_SYNC_VERSION` differs | Match versions; re-export if needed |
| db-sync replays from old slot / errors | Missing or stale `ledger-state` | Re-copy `ledger-state` or `import-state` from source |
| `get_block` much lower than manifest | Restore incomplete | Re-run `restore` into a fresh DB |
| db-sync idle, node ahead | Normal briefly | Wait; db-sync catches up from node socket |
| Chain rollback on network | Rare fork / upgrade | Set `DB_SYNC_ROLLBACK_SLOT` in `env` per IOG docs, then restart |

For a network rollback, IOG documents using `--rollback-to-slot`; this repo passes it via `DB_SYNC_ROLLBACK_SLOT` in `env`.

## Script reference

| Command | Purpose |
|---------|---------|
| `scripts/dbsync.sh export` | Dump live DB to `migration/db/` |
| `scripts/dbsync.sh export-state` | Archive `ledger-state` to `migration/ledger-state.tar.gz` |
| `scripts/dbsync.sh restore` | Restore from `migration/db/` (or `snapshot/db/`) |
| `scripts/dbsync.sh import-state` | Extract ledger state from migration archive |
| `scripts/dbsync.sh get_block` | Latest block in DB (sanity check) |

See also `scripts/dbsync.sh help` and [Cardano DBSync installation](03-cardano-dbsync-installation.md).

---
