# Cardano Node installation

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. **Cardano Node installation**
2. [Mithril Node installation](02-mithril-installation.md)
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
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

This table describes the env variables you most likely need to adjust to suit your system and their available options.
Read through these options before proceeding to the Node installation.

ENV variables


|                        |                                           |                                                                                                                                                                                                                                                            |
| ---------------------- | ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `COMPOSE_PROJECT_NAME` | `cardano`                                 | Used to name the docker container (only required if using docker)                                                                                                                                                                                          |
| `NODE_NETWORK`         | `sanchonet` `preview` `preprod` `mainnet` | One of the supported Cardano networks                                                                                                                                                                                                                      |
| `NODE_VERSION`         | `11.0.1`                                  | The current node version. Must be > the version defined here. Binaries are downloaded from [IntersectMBO cardano-node releases](https://github.com/intersectmbo/cardano-node/releases). Linux and macOS arm64 builds require node version 10.6.2 or later. |
| `NODE_HOME`            | `"/home/upstream/Cardano"`                | The home folder for your node, usually the root of this repository.                                                                                                                                                                                        |
| `NODE_TYPE`            | `relay` `producer` `cold`                 | The type of node you are running.                                                                                                                                                                                                                          |
| `NODE_USER`            | `upstream`                                | The user running the node.                                                                                                                                                                                                                                 |
| `NODE_BUILD`           | `0` `1` `2`                               | The build type. 0 = do not build or download binaries. 1 = downloads node binaries. 2 = builds node binaries from source.                                                                                                                                  |
| `NODE_PORT`            | `7777`                                    | The local node port.                                                                                                                                                                                                                                       |
| `NODE_HOSTADDR`        | `0.0.0.0`                                 | The local node host address.                                                                                                                                                                                                                               |
| `NODE_KOIOS_API`       | `API endpoint`                            | API endpoint for koios, used to fetch pool data.                                                                                                                                                                                                           |
| `NODE_SANCHO_CC_API`   | `API endpoint`                            | API endpoint for sanchonet, used to fetch pool data if using sanchonet, replaces the NODE_KOIOS_API.                                                                                                                                                       |
| `MITHRIL_VERSION`      | `2524.0`                                  | Your mithril version. Must be > the version defined here.                                                                                                                                                                                                  |
| `MITHRIL_RELAY_HOST`   | `http:192.168.X.X`                        | Your mithril relay host address excluding port.                                                                                                                                                                                                            |
| `MITHRIL_RELAY_PORT`   | `1234`                                    | Your mithril relay port.                                                                                                                                                                                                                                   |
| `BIN_PATH`             | `$HOME/local/bin`                         | Your users local bin path.                                                                                                                                                                                                                                 |
| `PACKAGER`             | `apt-get`                                 | System package manager.                                                                                                                                                                                                                                    |
| `SERVICE_PATH`         | `/etc/systemd/system`                     | System service path.                                                                                                                                                                                                                                       |


### Node install

> IMPORTANT - Skip the node install and mithril steps for local docker environments.

Get started by creating a directory and pulling this repo, and edit the env file (see table below for env descriptions
and configure).

```shell
mkdir Cardano && cd Cardano
git clone https://github.com/devhalls/spo-operational-scripts.git .
git checkout v1.0.2 
```

Create and edit your env file:

```shell
cp -p env.example env && nano env
```

When your env is configured, run the installation.

```shell
scripts/node.sh install
```

### Mithril sync

Once installation is complete, download the mithril binaries and run mithril sync.

```shell
scripts/node.sh mithril download
scripts/node.sh mithril sync
```

### Node start, stop, and restart

After installation is complete, you can start, stop, or restart the node service.

```shell
scripts/node.sh start
scripts/node.sh stop
scripts/node.sh restart
```

### Node update

When you would like to update the node, edit the env with your new target NODE_VERSION and run the node update script.
It's not recommended to 'downgrade' a node unless you are confident you know what you are doing.

```shell
nano env
scripts/node.sh update 
```

### Firewall

This is an example of allowing the node port through a firewall; it's expected you will secure your node as appropriate
for mainnet releases.

```shell
# Allow SSH
sudo ufw allow OpenSSH

# Allow node traffic
sudo ufw allow $NODE_PORT/tcp

# Restart any apply rule
sudo ufw disable
sudo ufw enable
```

---

