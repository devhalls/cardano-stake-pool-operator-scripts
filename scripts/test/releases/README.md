# Release test manifests

Each repo release (`NODE_VERSION`, e.g. `11.0.1`) is described by manifest files in this directory. Smoke tests load these to verify configuration matches the release contract.

## Files per release

| File | Purpose |
|------|---------|
| `<version>.manifest` | Env vars: `REQUIRED`, `OPTIONAL`, `PIN` |
| `<version>.docker.manifest` | Extra env `PIN` lines for Docker (`env.docker`) |
| `<version>.services.manifest` | Systemd templates, optional components, packaged units, db-sync schema head |

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
5. Run `./scripts/test.sh smoke --release <version>` (or `./docker/script.sh test.sh smoke`).

## Schema head

`SCHEMA_HEAD` must be the latest `migration-*.sql` under [`services/schema/`](../../services/schema/) shipped for the pinned `DB_SYNC_VERSION`. Update it when db-sync schema migrations are added for a new db-sync release.
