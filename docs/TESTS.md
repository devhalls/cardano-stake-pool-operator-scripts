# Integration tests

Script integration tests for the SPO operational toolkit. Each case runs the same `scripts/*.sh` entry points used in production, with per-test pass, fail, or skip reporting.

[README](../README.md) · [scripts/test.sh](../scripts/test.sh) · [Release manifests](../scripts/test/releases/) · [docker/fixture.sh](../docker/fixture.sh) (wallet/pool setup, not part of `test.sh`)

**Summary:** `smoke` validates env and services against versioned manifests. `integration` runs read-only chain queries when a socket is available. Use `--report` to refresh the generated results section at the bottom of this file.

---

## Prerequisites

### Docker (recommended for integration)

1. Start the stack: `./docker/run.sh up -d --build`
2. Wait until the node is synced and the socket exists at `/ipc/node.socket` inside the container.
3. Optional wallet integration tests: create keys with [docker/fixture.sh](../docker/fixture.sh) and fund `payment.addr` via the [testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet).

### Local

1. Copy `env.example` to `env` and configure paths.
2. **smoke** runs without a node; **integration** skips automatically if the socket is unavailable.

---

## Running tests

### Docker (same pattern as other scripts)

```shell
# From repository root
./docker/script.sh test.sh smoke
./docker/script.sh test.sh integration
./docker/script.sh test.sh all
./docker/script.sh test.sh list

# Update generated results in this file (requires docs/ volume — see below)
./docker/script.sh test.sh smoke --report
./docker/script.sh test.sh integration --report
./docker/script.sh test.sh report
```

**Updating docs from Docker:** `test.sh` writes to `$NODE_HOME/docs/TESTS.md`, which is this file on the host via the `docs/` bind mount. If you see `Docs path not available`, recreate the node container so the volume is applied:

```shell
./docker/run.sh up -d
```

### Inside the container

```shell
docker exec -it node bash
$NODE_HOME/scripts/test.sh smoke
$NODE_HOME/scripts/test.sh smoke --report
```

### Local / sos

```shell
./scripts/test.sh smoke
./sos test integration
./scripts/test.sh all --verbose
./scripts/test.sh report
```

### Options

| Flag | Description |
|------|-------------|
| `--verbose` | Print output for passing tests (failures always show output) |
| `--report` | After the run, update the generated results section in this file |
| `--release <VERSION>` | Validate env against `scripts/test/releases/<VERSION>.manifest` (default: `$NODE_VERSION`) |

---

## Test suites

| Suite | Mutates state | Requires socket | Requires funded wallet |
|-------|---------------|-----------------|------------------------|
| `smoke` | No | No | No |
| `integration` | No | Yes | No (wallet query tests skip without keys) |

`test.sh report` and `test.sh all` run **smoke**, then **integration**. Destructive setup (keys, registration, pool, DRep) stays in [docker/fixture.sh](../docker/fixture.sh), not in `test.sh`.

---

## Smoke test coverage

| Test | What it validates |
|------|-------------------|
| `smoke_env_release` | Every env var in the release manifest: set, required non-empty, `PIN` values match |
| `smoke_env_template_drift` | `env.example` (local) or `env.docker` (Docker) keys stay in sync with the manifest |
| `smoke_services_release` | Systemd templates (required + optional components), packaged units, db-sync schema when installed |
| `smoke_config_source` | Node config present (repo `configs/` or installed `$NETWORK_PATH/config.json`) |
| `smoke_cardano_cli` | `cardano-cli` available (`node.sh version`) |
| `smoke_help_*` | Each script exposes a `Usage:` help block |
| `smoke_install_validate` | Fresh install pre-check (skipped when keys already exist) |

---

## Release manifests (version contract)

Smoke tests treat **`NODE_VERSION`** (or `--release <VERSION>`) as the repo release id. Contracts live under [`scripts/test/releases/`](../scripts/test/releases/) — see [`releases/README.md`](../scripts/test/releases/README.md) for maintainer steps.

### Env (`<version>.manifest` + optional `<version>.docker.manifest`)

- **Local:** template file is [`env.example`](../env.example)
- **Docker:** template file is [`env.docker`](../env.docker) (mounted at `$NODE_HOME/env.docker`)
- **`REQUIRED`** — must be non-empty after `source env` + `common.sh`
- **`OPTIONAL`** — may be empty (ngrok, mithril aggregator, icebreaker secrets, etc.)
- **`PIN`** — must equal the pinned value for that release (e.g. `NODE_VERSION`, `DB_SYNC_VERSION`)

`smoke_env_template_drift` fails if a key exists in the template but not in the manifest, or vice versa.

**Docker vs local:** the base manifest always applies; `*.docker.manifest` applies only in Docker for extra `PIN` values (socket path, mithril version, etc.). Output includes `env_profile=docker` or `env_profile=local`.

### Services (`<version>.services.manifest`)

| Line type | Meaning |
|-----------|---------|
| `SERVICE` | Required stack (e.g. `cardano-node.service`); template must exist; deployed unit must match render when installed |
| `OPTIONAL_SERVICE` | Optional stack (db-sync, mithril, ngrok, icebreaker); skipped when not deployed; must match render when installed |
| `UNIT_STATIC` / `OPTIONAL_UNIT_STATIC` | Templates without substitution (e.g. `squid.service`) |
| `PACKAGED` | Env service name must match the distro unit (`prometheus.service`, etc.) |
| `SCHEMA_PIN` / `SCHEMA_HEAD` | Only when db-sync is installed (`$DB_SYNC` binary or `$DB_SYNC_PATH/schema` migrations present) |

**Docker vs local:** templates are read from `$REPO_ROOT/services` (mounted in Docker). Systemd deploy diffs are skipped in Docker / non-systemd hosts; template and schema bundle checks still run.

**Optional installs:** node-only setups without db-sync, mithril, ngrok, or icebreaker report `optional component not installed` and do not fail. Schema pins are skipped when db-sync is not installed.

```shell
./docker/script.sh test.sh smoke --release 11.0.1
```

---

## What developers must maintain

When you change a **release** (node, db-sync, mithril, schema, or env layout):

1. **`env.example`** and **`env.docker`** — keep keys aligned; docker-only values stay in `env.docker`.
2. **`scripts/test/releases/<version>.manifest`** — add/update `REQUIRED` / `OPTIONAL` / `PIN` for every env key.
3. **`scripts/test/releases/<version>.docker.manifest`** — Docker-only `PIN` overrides.
4. **`scripts/test/releases/<version>.services.manifest`** — `SERVICE` lines, substitution vars, `SCHEMA_HEAD` when migrations change.
5. **`configs/node/<version>/<network>/`** — config trees for pinned `NODE_VERSION` / networks.
6. Run **`./docker/script.sh test.sh smoke`** before tagging; use **`--report`** to refresh generated results below.

Adding a new release (e.g. `12.0.0`): copy all three manifest files from the previous version, update pins and schema head, then run smoke with `--release 12.0.0`.

---

## Integration query coverage

Requires a synced node and socket. Core chain queries always run; wallet and producer queries skip when keys or `NODE_TYPE` are absent.

| Group | Tests |
|-------|-------|
| Tip | `slot`, `epoch`, `block`, `hash` |
| Params | `minPoolCost`, `stakeAddressDeposit`, `params.json` written |
| Metrics | full export, `cardano_node_metrics` series present |
| Config | `config.json` readable |
| KES period | `kes_period` (uses genesis + tip) |
| Wallet | `uxto`, `rewards`, `key payment.addr` (skip until keys exist — use `docker/fixture.sh`) |
| Producer | `kes`, `leader next` (needs `NODE_TYPE=producer` + pool keys) |

---

## Generated results

Updated automatically by `test.sh --report` or `test.sh report`. Do not edit the block between the markers by hand.

<!-- TEST_RESULTS_START -->
## Last run

- **Time:** 2026-05-28 00:18:05 UTC
- **Git:** n/a
- **Environment:** docker | network=sanchonet | type=relay
- **Suite:** all
- **Summary:** passed=27 failed=0 skipped=6

### Results

```
PASS | smoke_env_release
PASS | smoke_env_template_drift
PASS | smoke_services_release
PASS | smoke_config_source
PASS | smoke_cardano_cli
PASS | smoke_help_address
PASS | smoke_help_query
PASS | smoke_help_pool
PASS | smoke_help_tx
PASS | smoke_help_govern
PASS | smoke_help_node
PASS | smoke_help_dbsync
PASS | smoke_help_network
PASS | smoke_help_midnight
PASS | smoke_help_node_install
SKIP | smoke_install_validate | keys directory already exists (installed environment)
PASS | integration_query_tip_slot
PASS | integration_query_tip_epoch
PASS | integration_query_tip_block
PASS | integration_query_tip_hash
PASS | integration_query_params_min_pool_cost
PASS | integration_query_params_stake_deposit
PASS | integration_query_params_writes_json
PASS | integration_query_metrics
PASS | integration_query_metrics_cardano_series
PASS | integration_node_version
PASS | integration_query_config_json
PASS | integration_query_kes_period
SKIP | integration_query_uxto | payment.addr missing — create keys with docker/fixture.sh address
SKIP | integration_query_rewards | stake.addr missing — create keys with docker/fixture.sh address
SKIP | integration_query_key_payment_addr | payment.addr key missing
SKIP | integration_query_kes | NODE_TYPE=relay — kes query requires producer
SKIP | integration_query_leader_next | NODE_TYPE=relay — leader query requires producer
```
<!-- TEST_RESULTS_END -->
