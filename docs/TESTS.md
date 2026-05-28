# Tests

Script integration tests for the SPO operational toolkit. Tests invoke the same `scripts/*.sh` entry points used in production and in [docker/fixture.sh](../docker/fixture.sh), with per-case pass/fail reporting.

## Prerequisites

### Docker (recommended for integration and fixture suites)

1. Start the stack: `./docker/run.sh up -d --build`
2. Wait until the node is synced and the socket exists at `/ipc/node.socket` inside the container.
3. For **fixture** register/submit flows, fund `payment.addr` via the [testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet).

### Local

1. Copy `env.example` to `env` and configure paths.
2. **smoke** runs without a node; **integration** and **fixture** skip automatically if the socket is unavailable.

## Running tests

### Docker (same pattern as other scripts)

```shell
# From repository root
./docker/script.sh test.sh smoke
./docker/script.sh test.sh integration
./docker/script.sh test.sh fixture address
./docker/script.sh test.sh all
./docker/script.sh test.sh list

# Update generated results below
./docker/script.sh test.sh report
```

### Inside the container

```shell
docker exec -it node bash
$NODE_HOME/scripts/test.sh smoke
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

## Release manifests (version contract)

Smoke tests treat **`NODE_VERSION`** (or `--release <VERSION>`) as the repo release id. Contracts live under [`scripts/test/releases/`](../scripts/test/releases/) — see [`releases/README.md`](../scripts/test/releases/README.md) for maintainer steps.

### Env (`<version>.manifest` + optional `<version>.docker.manifest`)

- **Local:** template file is [`env.example`](../env.example)
- **Docker:** template file is [`env.docker`](../env.docker) (mounted at `$NODE_HOME/env.docker`)
- **`REQUIRED`** — must be non-empty after `source env` + `common.sh`
- **`OPTIONAL`** — may be empty (ngrok, mithril aggregator, icebreaker secrets, etc.)
- **`PIN`** — must equal the pinned value for that release (e.g. `NODE_VERSION`, `DB_SYNC_VERSION`)

`smoke_env_template_drift` fails if a key exists in the template but not in the manifest, or vice versa.

**Docker vs local:** base manifest always applies; `*.docker.manifest` applies only in Docker for extra `PIN` values (socket path, mithril version, etc.). Output includes `env_profile=docker` or `env_profile=local`.

### Services (`<version>.services.manifest`)

Validates deployable artefacts for the same release:

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
# Validate a specific release contract
./docker/script.sh test.sh smoke --release 11.0.1
```

## What developers must maintain

When you change a **release** (node, db-sync, mithril, schema, or env layout):

1. **`env.example`** and **`env.docker`** — keep keys aligned; docker-only values stay in `env.docker`.
2. **`scripts/test/releases/<version>.manifest`** — add/update `REQUIRED`/`OPTIONAL`/`PIN` for every env key.
3. **`scripts/test/releases/<version>.docker.manifest`** — Docker-only `PIN` overrides.
4. **`scripts/test/releases/<version>.services.manifest`** — `SERVICE` lines (env var, template, substitution vars), `SCHEMA_HEAD` when migrations change.
5. **`configs/node/<version>/<network>/`** — config trees for pinned `NODE_VERSION` / networks.
6. Run **`./docker/script.sh test.sh smoke`** before tagging; use **`test.sh report`** to refresh generated results below.

Adding a new release (e.g. `12.0.0`): copy all three manifest files from the previous version, update pins and schema head, then run smoke with `--release 12.0.0`.

## Suites

| Suite | Mutates state | Requires socket | Requires funded wallet |
|-------|---------------|-----------------|------------------------|
| `smoke` | No | No | No |
| `integration` | No | Yes | No |
| `fixture` | Yes | Yes | For register/submit steps |

## Fixture subcommands

Run a single flow (same steps as `docker/fixture.sh`):

```shell
./docker/script.sh test.sh fixture address
./docker/script.sh test.sh fixture address_register
./docker/script.sh test.sh fixture spo
./docker/script.sh test.sh fixture spo_register <relayIp> <port> <metadataUrl>
./docker/script.sh test.sh fixture drep <metadataUrl>
./docker/script.sh test.sh fixture drep_register
./docker/script.sh test.sh fixture drep_delegate
```

Environment overrides for defaults:

- `FIXTURE_RELAY_ADDR`, `FIXTURE_RELAY_PORT`, `FIXTURE_METADATA_URL`

## Fixture parity (test → commands)

| Test group | Script commands |
|------------|-----------------|
| `fixture_address_*` | `address.sh generate_payment_keys`, `generate_stake_keys`, `generate_payment_address`, `generate_stake_address` |
| `fixture_address_register` | `query.sh params stakeAddressDeposit`, `address.sh generate_stake_reg_cert`, `tx.sh stake_reg_raw`, `stake_reg_sign`, `submit` |
| `fixture_spo_*` | `query.sh params`, `kes_period`, `pool.sh generate_kes_keys`, `generate_node_keys`, `generate_node_op_cert`, `generate_vrf_keys` |
| `fixture_spo_register` | `pool.sh generate_pool_meta_hash`, `generate_pool_reg_cert`, `address.sh generate_stake_del_cert`, `tx.sh pool_reg_*`, `submit`, `pool.sh get_pool_id` |
| `fixture_drep_*` | `govern.sh drep_keys`, `drep_id`, `drep_cert`, `tx.sh drep_reg_*`, `submit` |
| `fixture_drep_delegate` | `govern.sh drep_id`, `address.sh generate_stake_vote_cert`, `tx.sh build/sign/submit` (uses `$DELE_VOTE_CERT`, `$PAYMENT_KEY`, `$STAKE_KEY`) |

## Stateful caveats

- Re-running **address** key tests fails if `$NETWORK_PATH/keys` already exists; remove keys or use a fresh container volume.
- **spo_register** and **drep** require a metadata URL argument (public HTTP URL for on-chain metadata).
- Interactive overwrite prompts in scripts are avoided when keys already exist — those tests are skipped with a reason.

## Generated results

<!-- TEST_RESULTS_START -->
## Last run

- **Time:** 2026-05-27 23:19:52 UTC
- **Git:** 9a73b57
- **Environment:** local | network=sanchonet | type=relay
- **Suite:** all
- **Summary:** passed=14 failed=0 skipped=3

### Results

```
PASS | smoke_env_node_network
PASS | smoke_env_network_path
PASS | smoke_config_source
SKIP | smoke_cardano_cli | cardano-cli not found at /home/ubuntu/local/bin/sanchonet/cardano-cli (skipped outside docker/install)
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
PASS | smoke_install_validate
SKIP | integration_suite | node socket not available at /ipc/node.socket
SKIP | fixture_suite | node socket not available at /ipc/node.socket
```
<!-- TEST_RESULTS_END -->
