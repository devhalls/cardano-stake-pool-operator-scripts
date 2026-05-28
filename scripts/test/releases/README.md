# Release test manifests

Each repo release (`NODE_VERSION`, e.g. `11.0.1`) is described by manifest files in this directory. Smoke tests load these to verify configuration matches the release contract.

## Files per release

| File | Purpose |
|------|---------|
| `<version>.manifest` | Env vars: `REQUIRED`, `OPTIONAL`, `PIN` — validated in `env`, `env.example`, `env.docker`, and runtime shell |
| `<version>.docker.manifest` | Extra env `PIN` lines for Docker (`env.docker` and container `env`) |
| `<version>.services.manifest` | Systemd unit templates (existence, format, placeholders), deploy diff, db-sync schema |
| `<version>.configs.manifest` | Per-network files under `configs/node/<version>/<network>/` |
| `<version>.build.manifest` | Source-build lib pins (flake.lock), GHC/Cabal, `node/build.sh` / `node/download.sh` contract |

## When bumping a release

1. Copy the previous release’s three manifest files to the new version (e.g. `12.0.0.*`).
2. Update **`PIN`** lines in `.manifest` / `.docker.manifest` to match `env.example`, `env.docker`, and dependency versions (`DB_SYNC_VERSION`, `MITHRIL_VERSION`, etc.).
3. Regenerate or extend the base `.manifest` from `env.example`:
   ```shell
   OPTIONAL='NGROK_TOKEN NGROK_REGION ...'
   grep -E '^[A-Z][A-Z0-9_]*=' ../../env.example | cut -d= -f1 | while read -r k; do
     echo " $OPTIONAL " | grep -q " $k " && echo "OPTIONAL $k" || echo "REQUIRED $k"
   done
   ```
4. Update **`.services.manifest`** if templates, `SERVICE` / `OPTIONAL_SERVICE` lines, substitution lists, or db-sync schema head migration change.
5. Update **`.configs.manifest`** when adding/removing network config files under `configs/node/<version>/`.
6. Update **`.build.manifest`** when `cardano-node` tag flake.lock changes (iohk-nix / libsodium / secp / blst) or supported GHC/Cabal changes.
7. Keep **`env`**, **`env.example`**, and **`env.docker`** in sync with the env manifests (same key set; `PIN` values per file).
8. Run `./scripts/test.sh smoke --release <version>` (or `./docker/script.sh test.sh smoke`). `smoke_build_release` resolves upstream flake.lock (needs network).

## Schema head

`SCHEMA_HEAD` must be the latest `migration-*.sql` under [`configs/schema/`](../../../configs/schema/) shipped for the pinned `DB_SYNC_VERSION`. Update it when db-sync schema migrations are added for a new db-sync release.
