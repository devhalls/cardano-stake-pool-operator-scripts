# Local Docker

[README](../README.md)

---

We use docker containers to run local node simulations on Cardano testnets. Docker should not be used for your mainnet
deployments.

```shell
# Build and start the docker containers
./docker/run.sh up -d --build 
```

Once your containers are running, you can run the fixtures and any node operation scripts using the docker wrapper:

```shell
# View fixtures help to generate address credentials
./docker/fixture.sh help

# Run scripts in the container, e.g.
./docker/script.sh node.sh view
./docker/exec.sh node scripts/query.sh uxto

# OR Connect to the cardano node container and work directly from there
docker exec -it node bash

# Run tests (see docs/TESTS.md)
./docker/script.sh test.sh smoke
./docker/script.sh test.sh integration
./docker/script.sh test.sh all
./docker/script.sh test.sh report
```

See [docs/TESTS.md](docs/TESTS.md) for smoke/integration coverage and generated test output. Wallet and pool setup use `./docker/fixture.sh`, not `test.sh`.

### Managing the containers

```shell
# Restart a container e.g. prometheus
./docker/run.sh restart prometheus

# Rebuld containers if changes have been made to compose OR .env file
./docker/run.sh up -d --build 
```

---

