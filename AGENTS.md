# Agent guide — spo-operational-scripts

Bash toolkit for **Cardano Stake Pool Operators**: install and run nodes, optional Mithril / db-sync / Midnight stacks, and on-chain registration flows (pool, DRep, Constitutional Committee). Operational docs live under `docs/`; this file is for humans and AI assistants working in the repo.

## What this repository is

| Area | Purpose |
|------|---------|
| `scripts/*.sh` | Production CLI entry points (`address`, `query`, `pool`, `tx`, `govern`, `node`, `dbsync`, `network`, `midnight`) |
| `scripts/node/` | Build, download, install, update, mithril, icebreaker helpers |
| `scripts/test/` | Smoke + integration test harness (`test.sh`); release manifests under `releases/` |
| `configs/node/<version>/<network>/` | Pinned node config bundles (e.g. `11.0.1` × `mainnet` / `preview` / `preprod` / `sanchonet`) |
| `services/` | Systemd unit templates + db-sync SQL schema migrations |
| `docker/` | Local testnet stack (not for mainnet); `docker/script.sh` wraps `scripts/` in the container |
| `docker/fixture.sh` | Destructive key/register flows for dev (not `test.sh fixture`) |
| `env.example` / `env.docker` | Definitive env templates; runtime `env` is gitignored |

**Release pin:** `NODE_VERSION=11.0.1` (and matching manifests). Env, services, configs, and build contracts are validated in smoke tests.

## Architecture

```
env (+ env.docker in Docker)
  → scripts/common.sh (sources env, sets CONFIG_SOURCE, NETWORK_ARG, CONFIG_PATH, CONFIG_DOWNLOADS)
  → scripts/<name>.sh (dispatch subcommands; `help` exits 1 with Usage block)
```

- **Networks:** `mainnet`, `preprod`, `preview`, `sanchonet` (magic in `NETWORK_ARG`).
- **Node types:** `relay`, `producer`, `cold` — cold/producer split for key safety; many `tx`/`pool` steps assume copy-between-machines workflow documented in `docs/`.
- **Binaries:** `NODE_BUILD` `0` = none, `1` = download from IntersectMBO releases, `2` = build from source (`scripts/node/build.sh`, GHC/Cabal from env).
- **Optional stack:** db-sync, mithril signer/relay, ngrok, BlockFrost icebreaker, prometheus/grafana — gated by env vars and `*.services.manifest`.

## Documentation map

| Doc | Content |
|-----|---------|
| [README.md](README.md) | Entry point, assumptions, links to all guides |
| [docs/README.md](docs/README.md) | Full docs index |
| [docs/cardano-node-installation.md](docs/cardano-node-installation.md) | Env table, install, firewall |
| [docs/mithril-installation.md](docs/mithril-installation.md) | Mithril signer/relay |
| [docs/cardano-dbsync-installation.md](docs/cardano-dbsync-installation.md) | Postgres + db-sync |
| [docs/midnight-installation.md](docs/midnight-installation.md) | Partner-chain Docker (separate `midnight/` tree when present) |
| [docs/docker-installation.md](docs/docker-installation.md) | Local Docker workflow |
| [docs/registering-stake-pool.md](docs/registering-stake-pool.md) | Pool registration |
| [docs/managing-stake-pool.md](docs/managing-stake-pool.md) | Ops, KES, governance, retirement |
| [docs/registering-drep.md](docs/registering-drep.md) | DRep |
| [docs/registering-constitutional-committee.md](docs/registering-constitutional-committee.md) | CC member |
| [docs/blockfrost-icebreaker.md](docs/blockfrost-icebreaker.md) | Icebreaker on relay |
| [docs/registering-midnight-validator.md](docs/registering-midnight-validator.md) | Midnight validator |
| [docs/TESTS.md](docs/TESTS.md) | `test.sh` suites and manifests |

## Running scripts

```shell
# From repo root (after cp env.example env and editing)
scripts/node.sh install
scripts/query.sh tip slot

# Optional wrapper
./sos query tip slot

# Docker (testnets)
./docker/script.sh test.sh smoke
./docker/fixture.sh address
```

Help for any script: `scripts/<script>.sh help` (exit code **1**, output must include `Usage:`).

## Tests

```shell
./scripts/test.sh smoke          # env, services, configs, build contracts; no chain
./scripts/test.sh integration    # read-only queries; needs socket
./scripts/test.sh all            # smoke + integration
./scripts/test.sh list
```

- Manifests: `scripts/test/releases/<version>.{manifest,docker.manifest,services.manifest,configs.manifest,build.manifest}`.
- Do not re-enable destructive `test.sh fixture`; use `docker/fixture.sh`.
- `run_test` skip = exit code **2** (not a failure count).

## Conventions when changing code

1. **Bash style:** Match existing scripts — `source common.sh`, `print` for messages, `_foo_fail` helpers, `case $1 in` dispatch, header `Usage:` comment block.
2. **Env changes:** Update `env.example`, `env.docker`, and `scripts/test/releases/<version>.manifest` (and `.docker.manifest` if Docker-only pins). Run smoke.
3. **New config file per network:** Add to `configs/node/<version>/<network>/` and `*.configs.manifest`.
4. **New systemd template:** Add to `services/` and `*.services.manifest` with correct `SERVICE` / substitution vars.
5. **Version bump:** Copy all release manifests; update pins, schema head, build flake pins; see `scripts/test/releases/README.md`.
6. **Minimal diffs:** No drive-by refactors; this repo favors explicit shell over heavy abstraction.
7. **Secrets:** Never commit `env`, keys under `$NETWORK_PATH/keys`, or API tokens.

## What this repo is not

- Not a Cardano wallet or dApp — it wraps `cardano-cli` / `cardano-node` for operators.
- Not a single Nix/Haskell application — primary language is **bash**; node binaries are external.
- Not safe to run registration txs on mainnet without understanding cold/hot key separation in the docs.
- No bundled custom **MCP server** — agents use repo files and shell; add MCP only if you need a dedicated tool protocol for external automation.

## Common pitfalls for agents

- Assuming `env` is in git — it is not; validate against `env.example` / `env.docker` in tests.
- Docker `env` stale after `env.docker` edit — entrypoint copies once; recreate container or `cp env.docker env`.
- Relay Prometheus metrics may omit `slotNum`; integration tests accept `cardano_node_metrics_*` operational series.
- `integration` wallet/producer tests skip without keys or when `NODE_TYPE=relay`.
- `platform_ctl` / systemd deploy diffs skipped in Docker; template checks still run.

## Suggested focus by task

| Task | Read first |
|------|------------|
| Install node | `docs/cardano-node-installation.md`, `scripts/node/install.sh` |
| Query chain | `scripts/query.sh`, `docs/managing-stake-pool.md` (monitoring section) |
| Pool register | `docs/registering-stake-pool.md`, `scripts/pool.sh`, `scripts/tx.sh` |
| Governance | `docs/registering-drep.md`, `scripts/govern.sh` |
| Tests / CI | `docs/TESTS.md`, `scripts/test/lib.sh` |
| Docker dev | `docs/docker-installation.md`, `docker/docker-compose.yaml` |
