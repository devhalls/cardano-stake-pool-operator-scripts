# Local Docker

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. [Mithril Node installation](02-mithril-installation.md)
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
4. [Midnight Node installation](04-midnight-installation.md)
5. [Midnight DBSync installation](05-midnight-dbsync-installation.md)
6. **Local Docker**

**Registration**
1. [Registering a Stake Pool](../registration/01-registering-stake-pool.md)
2. [Managing a Stake Pool](../registration/02-managing-stake-pool.md)
3. [Registering a DRep](../registration/03-registering-drep.md)
4. [Registering a Constitutional Committee member](../registration/04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](../registration/05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](../registration/06-registering-midnight-validator.md)

---

We use docker containers to run local node simulations on Cardano testnets. Docker should not be used for your mainnet
deployments.

```shell
# Build and start the docker containers
./docker/run.sh up -d --build
```

Node binaries are installed from `env.docker` (`NODE_VERSION`, `NODE_BUILD=1` download) by the container entrypoint. `docker/bin` is bind-mounted as `BIN_PATH` so downloads persist across restarts; if the on-disk binary does not match `NODE_VERSION`, the entrypoint runs `install binaries` automatically.

Once your containers are running, you can run the fixtures and any node operation scripts using the docker wrapper:

```shell
# View fixtures help to generate address credentials
./docker/fixture.sh help

# Run scripts in the container, e.g.
./docker/script.sh node.sh view

# OR Connect to the cardano node container and work directly from there
docker exec -it node bash

# Run tests (see ../TESTS.md)
./docker/script.sh test.sh smoke
./docker/script.sh test.sh integration
./docker/script.sh test.sh all
./docker/script.sh test.sh report
```

See [Integration and smoke tests](../TESTS.md) for smoke/integration coverage and generated test output. Wallet and pool setup use `./docker/fixture.sh`, not `test.sh`.

### Managing the containers

```shell
# Restart a container e.g. prometheus
./docker/run.sh restart prometheus

# Rebuild containers if changes have been made to compose OR .env file
./docker/run.sh up -d --build
```

### Stop and remove containers

`docker/run.sh` forwards to `docker compose` (uses `env.docker`):

```shell
./docker/run.sh down          # stop and remove containers
./docker/run.sh down -v       # also remove named volumes (socket, grafana data)
```

Bind-mounted data under `docker/node`, `docker/postgres`, and `docker/db-sync` is kept unless you delete those directories yourself.

### Missing or outdated configs

Bundled configs under `configs/node/11.0.1/<network>/` target cardano-node **11.0.1+** (`MinNodeVersion` 11.0.1; peer snapshots use `NetworkMagic`, `Point`, and `bigLedgerPools`). After changing `NODE_VERSION` or network files, refresh the container copy:

```shell
./docker/script.sh node.sh install configs
./docker/run.sh restart node
```

### Missing `config.json` after restart

If logs show `Skipping install` but `Yaml file not found: .../cardano-node/config.json`, the node binary is on disk but configs were not copied (common after wiping `docker/node` only). Fix without a full reinstall:

```shell
./docker/script.sh node.sh install configs
./docker/run.sh restart node
```

Or reset node data and recreate:

```shell
./docker/run.sh down
rm -rf docker/node
./docker/run.sh up -d --build
```

The entrypoint installs configs automatically when binaries exist but `config.json` is missing.

---

