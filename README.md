# Cardano Stake Pool Operator (SPO) scripts

Scripts and procedures for installing and managing a Cardano node, Mithril node, Midnight node, and operating
credentials for a Stake Pool, DRep or Constitutional Committee member.

[Upstream](https://upstream.org.uk/)
[Cardano](https://cardano.org/)
[Midnight](https://midnight.network/)
[Mithril](https://mithril.network/)
[DBSync](https://github.com/IntersectMBO/cardano-db-sync/)

For the community by Upstream Stake Pool [UPSTR](https://upstream.org.uk/cardano-staking/). Delegate to Upstream to help
support our work.

---

Repository file tree

```
tree --filesfirst -L 3

├── LICENSE
├── README.md
├── docs
│   └── TESTS.md
├── env.docker
├── env.example
├── docker
│   ├── config.prometheus.yml
│   ├── docker-compose.yaml
│   ├── Dockerfile.node
│   ├── entrypoint.node.sh
│   ├── exec.sh
│   ├── fixture.sh
│   ├── postgresql.conf
│   ├── run.sh
│   └── script.sh
├── metadata
│   ├── anchor.example.json
│   ├── drep.example.json
│   └── spo.example.json
├── scripts
│   ├── address.sh
│   ├── common.sh
│   ├── dbsync.sh
│   ├── govern.sh
│   ├── midnight.sh
│   ├── network.sh
│   ├── node.sh
│   ├── pool.sh
│   ├── query.sh
│   ├── test.sh
│   ├── tx.sh
│   ├── test
│   │   ├── fixture.sh
│   │   ├── integration.sh
│   │   ├── lib.sh
│   │   └── smoke.sh
│   └── node
│       ├── build.sh
│       ├── download.sh
│       ├── icebreaker.sh
│       ├── install.sh
│       ├── mithril.sh
│       └── update.sh
└── services
    ├── schema
        ├── migration-1-0000-20190730.sql
        ├── ...
        └── migration-4-0008-20240604.sql
    ├── blockfrost-platform.service
    ├── cardano-node.service
    ├── cardano-db-sync.service
    ├── grafana-mithril-dashboard.json
    ├── grafana-node-dashboard.json
    ├── mithril.service
    ├── ngrok.service
    ├── pgpass
    ├── prometheus.yml
    └── squid.service
```

Assumptions

1. Your OS, LAN network, ports, and user are already configured.
2. The Ngrok script requires you to know how to set up your own ngrok account and endpoints.
3. You are comfortable with cardano-node / cardano-cli and general SPO requirements.
4. You are comfortable with Linux and managing networks and servers.
5. You are able to set up your cold node by copying the binaries, scripts, and keys securely as required.



---

## Getting started

We divide our workflow in two main branches; **deployment**, covering node dependencies, configs and installs, and
**registrations**, covering stake pool, mithril, midnight, and other services requiring certificates.

**Deployment**

1. [Cardano Node installation](#node-installation)
2. [Mithril Node installation](#mithril-installation)
3. [Cardano DBSync installation](#dbsync-installation)
4. [Midnight Node installation](#midnight-installation)
5. [Midnight DBSync installation](#midnight-dbsync-installation)
6. [Local Docker](#docker-installation)

**Registrations**

1. [Registering a Stake Pool](#registering-a-stake-pool)
2. [Managing a Stake Pool](#managing-a-stake-pool)
3. [Registering a DRep](#registering-a-drep)
4. [Registering a Constitutional Committee member](#registering-a-constitutional-committee-member)
5. [BlockFrost Icebreaker](#blockfrost-icebreaker)
6. [Registering a Midnight Validator](#registering-a-midnight-validator)

**Overview**

Scripts are executed via their relative path (likely to change to a single executable)

```shell
scripts/address.sh help
scripts/dbync.sh help
scripts/govern.sh help
scripts/network.sh help
scripts/node.sh help
scripts/pool.sh help
scripts/query.sh help
scripts/tx.sh help
```

---

## Node installation

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

## Mithril installation

To operate as a mithril signer, you must have a synced block producer and relay. Mithril signers must operate using a
sentry architecture, where a mithril relay connects to the wider network and the mithril signer connects to the relay.
However, on testnets we operate the Mithril signer directly and do not install a relay.

### Mithril signer

```shell
# Check compatability with your nodes version
scripts/node.sh mithril check_compatability

# Edit the MITHRIL_VERSION in your env file, then update
nano env
scripts/node.sh mithril update

# Install the signer env and service
scripts/node.sh mithril install_signer_env
scripts/node.sh mithril install_signer_service
```

### Mithril update

When you would like to update mithril, edit `MITHRIL_VERSION` in your env file and run the update script.

```shell
nano env
scripts/node.sh mithril update
```

### Mithril relay

```shell
scripts/node.sh mithril install_squid
scripts/node.sh mithril configure_squid
```

## DBSync installation

DBSync runs alongside a cardano node and manages a postgres database populated with historical blockchain data. To
operate a DBSync instance, your node must first be fully synced.

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

### DBSync update

When you would like to update db-sync, edit `DB_SYNC_VERSION` in your env file and run the update script.

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

---

## Midnight installation

Operating a midnight node requires operating additional partner chain services. For midnight testnet this repository
contains a docker deployment separate from other stake pool node services.

Install docker and docker compose if needed:

- [Install Docker Engine](https://docs.docker.com/engine/install/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)

```shell
# Enter the directory
cd midnight

# Start / restart containers
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml restart

# Monitor the logs
docker logs -f --tail 100 cardano-ogmios
docker logs -f --tail 100 cardano-db-sync
docker logs -f --tail 100 db-sync-postgres
docker logs -f --tail 100 cardano-node
docker logs -f --tail 100 midnight-node

# Query the Ogmios service health
curl -s localhost:1337/health | jq '.'

# Query the sidechain status
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "sidechain_getStatus",
    "params": [],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Query your node peers
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "system_peers",
    "params": [],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Query the committee
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "sidechain_getEpochCommittee",
    "params": [245148],
    "id": 1
}' http://127.0.0.1:9944 | jq
```

## Midnight DBSync installation

For midnight DBSync testnet we extend our existing docker compose
with [compose-indexer.yml](midnight/compose-indexer.yml).
This contains the additional services required to operate a Midnights archive node and Midnight DBSync, while keeping
our
validator node separate.

The only dependency with the other midnight docker services is Cardano DBSync postgres, which is necessary for an
archive node. 

```shell
# Enter the directory
cd midnight

# Make the .env and set the variables
cp .env.example .env
nano .env

# Start / restart containers
docker compose -f ./compose-partner-chains.yml up -d
docker compose -f ./compose-partner-chains.yml restart
```

You can then monitor the docker containers:

```shell
docker logs -f midnight-indexer-node
docker logs -f midnight-indexer-chain
docker logs -f midnight-indexer-wallet
docker logs -f midnight-indexer-nats
docker logs -f midnight-indexer-postgres
docker logs -f midnight-indexer-api
```

## Docker installation

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

## Registering a Stake Pool

To register a stake pool, you must have a running **fully synced** node. We can then generate the following assets:

pool assets


|                |                                |
| -------------- | ------------------------------ |
| `payment.vkey` | payment verification key       |
| `payment.skey` | payment signing key            |
| `payment.addr` | funded address linked to stake |
| `stake.vkey`   | staking verification key       |
| `stake.skey`   | staking signing key            |
| `stake.addr`   | registered stake address       |
| `node.skey`    | cold signing key               |
| `node.vkey`    | cold verification key          |
| `kes.skey`     | KES signing key                |
| `kes.vkey`     | KES verification key           |
| `vrf.skey`     | VRF signing key                |
| `vrf.vkey`     | VRF verification key           |
| `node.cert`    | operational certificate        |
| `node.counter` | issue counter                  |
| metadata url   | Public URL for metadata file   |
| metadata hash  | Hash of the json file          |


### Generate stake pool keys and certificates

Start your pool registration by generating node keys and a node operational certificate, along with your KES keys and
VRF keys.

```shell
# PRODUCER: Query network params and take note of the 'KES period'
scripts/query.sh params
scripts/query.sh kes_period

# COLD: Generate node keys and operational certificate
scripts/pool.sh generate_kes_keys
scripts/pool.sh generate_node_keys
scripts/pool.sh generate_node_op_cert <KES period>

# COPY: node.cert to your producer node
# PRODUCER: Generate your node vrf key
scripts/pool.sh generate_vrf_keys
```

### Generate payment and stake keys

Create payment keys, stake keys and generate addresses from the keys. Ensure you fund your payment address and query the
chain to confirm you have UXTOs.

```shell
# COLD: Generate payment and stake keys
scripts/address.sh generate_payment_keys
scripts/address.sh generate_stake_keys
scripts/address.sh generate_payment_address
scripts/address.sh generate_stake_address

# COPY: The payment.addr and stake.addr to your producer node
# EXTERNAL: Fund your payment address (see faucet link at the bottom of this readme)
# PRODUCER: Query the address uxto to ensure funds arrived in your payment.addr
scripts/query.sh uxto
```

### Registering your stake address

Create a stake address certificate and submit the transaction to complete the registration.

```shell
# COLD: Get the stakeAddressDeposit value then generate a stake certificate
scripts/query.sh params stakeAddressDeposit
scripts/address.sh generate_stake_reg_cert <lovelace>

# COPY: stake.cert to your producer node
# PRODUCER: build stake registration tx  
scripts/tx.sh stake_reg_raw

# COPY: tx.raw to your cold node 
# COLD: Sign the stage registration transaction tx.raw
scripts/tx.sh stake_reg_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit
```

### Registering your stake pool

Create a pool registration certificate and submit the transaction to complete the registration.

```shell
# PRODUCER: Generate your metadata hash and take note along with the min pool cost
scripts/pool.sh generate_pool_meta_hash <metaUrl>
scripts/query.sh params minPoolCost

# COLD: Generate pool registration certificate and pool delegate certificate
scripts/pool.sh generate_pool_reg_cert <pledge> <cost> <margin> <metaUrl> <metaHash> --relay <relayAddr1>:<relayPort1> --relay <relayAddr2>:<relayPort2>
scripts/address.sh generate_stake_del_cert 
 
# COPY: pool.cert and deleg.cert to your producer node
# PRODUCER: build you pool cert raw transaction
scripts/tx.sh pool_reg_raw

# COPY: tx.raw to your cold node 
# COLD: Sign the pool certificate transaction tx.raw
scripts/tx.sh pool_reg_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit

# COLD: Now you have registered your pool, get your pool.id
scripts/pool.sh get_pool_id

# COPY: pool.id to your producer node, and to your replay node for convince later. 
```

### Edit topology and restart the producer

To complete pool registration, edit your topology to suit your replay configuration and restart your producer node.

```shell
# PRODUCER: Edit your typology and add your relay configuration
nano cardano-node/topology.json

# PRODUCER: Update your env NODE_TYPE=producer
nano env

# PRODUCER: Then restart the producer
scripts/node.sh restart
```

---

## Managing a Stake Pool

As a Stake Pool Operator, there are a few things you must do to keep a producing block producing pool.

When operating multiple nodes and networks, try
our [SPO Monitoring Scripts](https://github.com/devhalls/spo-monitor-scripts) solution for easier day-to-day monitoring.

### Monitoring your pool

Knowing what's going on under the hood is essential to running a node. The below commands offer a variety of data points
to monitor.

```shell
# Display the node service status
scripts/node.sh status

# Run the gLiveView script
scripts/node.sh view

# Watch the node service logs
scripts/node.sh watch

# Read file contents from the node directories 
scripts/query.sh config topology.json
scripts/query.sh key stake.addr

# Query your KES period and state
scripts/query.sh kes_period
scripts/query.sh kes_state

# Query the tip or chain params, with an optional param name
scripts/query.sh tip
scripts/query.sh tip epoch
scripts/query.sh params
scripts/query.sh params treasuryCut

# Query node prometheus metrics
scripts/query.sh metrics
scripts/query.sh metrics cardano_node_metrics_peerSelection_warm
```

### Monitoring with Grafana

View your node state via Grafana dashboards makes it easy to manage your nodes. Once you have installed the necessary
packages and configs, restart your nodes, and you can visit the dashboard.

- Dashboard: MONITOR_NODE_IP:3000
- Username: admin
- Password: admin (change your password after login)

```shell
# ALL NODES: Install prometheus explorer on all nodes
scripts/node.sh install prometheus_explorer

# MONITOR: Install grafana on the monitoring node only
scripts/node.sh install grafana

# ALL NODES: Check the service status
scripts/node.sh watch_prom_ex
scripts/node.sh status_prom_ex

# MONITOR: Check the service status
scripts/node.sh watch_prom
scripts/node.sh watch_grafana
scripts/node.sh status_prom
scripts/node.sh status_grafana

# ALL NODES: Restart the prometheus services
scripts/node.sh restart_prom

# MONITOR: Restart the grafana services
scripts/node.sh restart_grafana

# MONITOR: Edit your prometheus config to collect data from all your replays, then restart
sudo nano /etc/prometheus/prometheus.yml
scripts/node.sh restart_prom

# MONITOR: You may need to add the prometheus user to the folders group to avoid permission issues
sudo usermod -a -G upstream prometheus

# MONITOR: You may also need to change the user in the prometheus.yml if you still experience permissions issues
sudo nano /lib/systemd/system/prometheus-node-exporter.service
```

To enable metrics from external APIs, set the env API key in NODE_KOIOS_API and NODE_SANCHO_CC_API (if using sanchonet),
then run the following commands:

```shell
# MONITOR: create the pool.id file and paste in your 'Pool ID' which you can get from https://cardanoscan.io (or generate it on your cold device)
nano cardano-node/keys/pool.id

# MONITOR: Check you can retrieve stats, and check if theres no error in the response
scripts/pool.sh get_stats

# If successful (you see stats output) setup a crontab to fetch data periodically
crontab -e

# Get data from external api every hour at 5 past the hour
5 * * * * /home/upstream/Cardano/scripts/pool.sh get_stats >> /home/upstream/Cardano/cardano-node/logs/crontab.log 2>&1
```

### Rotate your KES

You must rotate your KES keys every 90 days, or you will not be able to produce blocks.

```shell
# PRODUCER: Check the current status and take note of the 'kesPeriod'
scripts/query.sh kes
scripts/query.sh kes_period

# COLD: Rotate the node
scripts/pool.sh rotate_kes <kesPeriod>

# COPY: node.cert and kes.skey to producer node
# PRODUCER: Restart the node
scripts/node.sh restart

# PRODUCER: Check the updates have applied
scripts/query.sh kes
```

### Leader schedule

Checking when you are due to mint blocks is essential to running your stake pool.

```shell
# PRODUCER: Check the next epoch leader schedule
scripts/query.sh leader next 

# PRODUCER: OR you can check the current epoch if needed
scripts/query.sh leader current

# COPY: Copy the out put ready to past to your monitor nodes grafana csv file
# MONITOR: Paste in the below file (if your runnong a testnet node with only a producer this is done automatically)  
sudo nano /usr/share/grafana/slots.csv
```

### Backing up your pool

It's vitally import you make multiple backups of your node cold keys. You can also back up your producer and relays to
simplify redeployment.

```
# COLD: Backup the keys.
.
├── $NETWORK_PATH/keys

# PRODUCER: Backup the below directories and env configuration, EXCLUDING the $NETWORK_PATH/db folder which contains the blockchain database.
.
├── env
├── metadata
├── $NETWORK_PATH
```

### Regenerate pool certificates

When you need to update your pool metadata, min cost, or other pool params, you must regenerate your `pool.cert` using
the same steps as when you first created these.

```shell
# PRODUCER: Generate your metadata hash and take note along with the min pool cost
scripts/pool.sh generate_pool_meta_hash <metaUrl>

# COLD: Generate pool registration certificate with a cost=0
scripts/pool.sh generate_pool_reg_cert <pledge> <cost> <margin> <metaUrl> <metaHash> --relay <relayAddr1>:<relayPort1> --relay <relayAddr2>:<relayPort2>

# COPY: pool.cert and deleg.cert to your producer node
# PRODUCER: build you pool cert raw transaction passing in 0 as a deposit for renewals
scripts/tx.sh pool_reg_raw 0

# COPY: tx.raw to your cold node 
# COLD: Sign the pool certificate transaction tx.raw
scripts/tx.sh pool_reg_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit
```

### Delegating your voting power

You have four possibilities when choosing how you wish to participate, listed below. Along with these you can also
register your stake address as a DRep and participate in Governance directly as your own representative:

1. delegate to a DRep who can vote on your behalf
2. delegate to a DRep script who can vote on your behalf
3. delegate your voting power to auto abstain
4. delegate your voting power to a vote of on-confidence

```shell
# COLD: Generate your vote delegation certificate using one of the 4 options:
scripts/address.sh generate_stake_vote_cert drep <drepId>
scripts/address.sh generate_stake_vote_cert script <scriptHash>
scripts/address.sh generate_stake_vote_cert abstain
scripts/address.sh generate_stake_vote_cert no-confidence

# PRODUCER: Build the tx.raw with the $DELE_VOTE_CERT
scripts/tx.sh stake_vote_reg_raw

# COPY: tx.raw to your cold node 
# COLD: Sign the transaction tx.raw
scripts/tx.sh stake_reg_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit
```

### Withdrawing stake pool rewards

To withdraw your SPO rewards, you will need to participate in Cardano Governance by delegating your stake address
voting power.

```shell
# PRODUCER: build you pool cert raw transaction
scripts/tx.sh pool_withdraw_raw

# COPY: tx.raw to your cold node 
# COLD: Sign the withdraw transaction tx.raw
scripts/tx.sh stake_reg_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit
```

### Vote on a governance action as a SPO

Running a Stake Pool requires participation in Cardano governance. From *time to time* you will need to cast your SPO
vote for various governance actions.

```shell
# PRODUCER: Query the govern action id then build the vote
scripts/govern.sh action <govActionId>

# PRODUCER: Optionally generate your vote anchor hash.
scripts/govern.sh hash <anchorUrl>

# COLD: cast your vote on your cold machine
scripts/govern.sh vote <govActionId> <govActionIndex> <'yes' | 'no' | 'abstain'> <anchorUrl> <anchorHash>

# COPY: vote.raw to your producer node
# PRODUCER: build the raw transaction with vote.raw as input 
scripts/tx.sh vote_raw

# COPY: tx.raw to your cold node 
# COLD: Sign the vote transaction tx.raw
scripts/tx.sh vote_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit
```

### Retiring your Stake Pool

If you decide you no longer wish to operate a stake pool, you can retire and claim back the registration deposit.

```shell
# PRODUCER: Get the retirement epoch window
poolRetireMaxEpoch=$(scripts/query.sh params poolRetireMaxEpoch)
epoch=$(scripts/query.sh tip epoch)
minRetirementEpoch=$(( ${epoch} + 1 ))
maxRetirementEpoch=$(( ${epoch} + ${poolRetireMaxEpoch} ))
echo earliest epoch for retirement is: ${minRetirementEpoch}
echo latest epoch for retirement is: ${maxRetirementEpoch}

# COLD: generate deregistration certificate ($POOL_DREG_CERT)
scripts/pool.sh generate_pool_dreg_cert <epoch>

# COPY: copy pool.dereg to producer
# PRODUCER: build a tx with the dregistration certificate 
scripts/tx.sh build 0 --certificate-file cardano-node/keys/pool.dereg

# COPY: copy temp/tx.raw to cold
# COLD: sign the transaction with your payment and node keys
scripts/tx.sh sign --signing-key-file cardano-node/keys/payment.skey --signing-key-file cardano-node/keys/node.skey

# COPY: copy temp/tx.signed to cold and submit
scripts/tx.sh submit 
```

---

## Registering a DRep

To register as a DRep you must have a running **fully synced** node. We can then generate the following assets:

DRep assets


|             |                       |
| ----------- | --------------------- |
| `drep.vkey` | DRep verification key |
| `drep.skey` | DRep signing key      |
| `drep.cert` | DRep certificate      |
| `drep.id`   | DRep ID               |


### Generate DRep keys and certificate

Start your DRep registration by generating keys and a DRep certificate.

```shell
# PRODUCER: Generate DRep keys and ID
scripts/govern.sh drep_keys
scripts/govern.sh drep_id 

# PRODUCER: Generate the DRep registration certificate assuming oyu have a public metadata URL
scripts/govern.sh drep_cert <url> 

# PRODUCER: Build a transaction with the drep certificate
scripts/tx.sh drep_reg_raw

# COPY: tx.raw to your cold node
# COLD: Sign the transaction
scripts/tx.sh drep_reg_sign

# COPY: tx.signed to your producer node
# PRODUCER: Submit the transaction
scripts/tx.sh submit
```

### Vote on a governance action as a DRep

Being a DRep requires participation in Cardano governance. From *time to time* you will need to cast your DRep vote for
various governance actions.

```shell
# PRODUCER: Query the govern action id then build the vote
scripts/govern.sh action <govActionId>

# COLD: cast your vote on your cold machine - to vote as a DRep ensure you pass the last param: 'drep'
scripts/govern.sh vote <govActionId> <govActionIndex> <'yes' | 'no' | 'abstain'> <anchorUrl> <anchorHash> drep

# COPY: vote.raw to your producer node
# PRODUCER: build the raw transaction with vote.raw as input 
scripts/tx.sh vote_raw

# COPY: tx.raw to your cold node 
# COLD: Sign the vote transaction tx.raw
scripts/tx.sh vote_sign drep

# COPY: tx.signed to your producer node
# PRODUCER: Submit the signed transaction 
scripts/tx.sh submit
```

---

## Registering a Constitutional Committee member

To register as a Constitutional Committee member, you must have a running **fully synced** node. We can then generate
the following assets:

Committee member assets


|                |                                  |
| -------------- | -------------------------------- |
| `cc-hot.vkey`  | Committee hot verification key   |
| `cc-hot.skey`  | Committee hot signing key        |
| `cc-cold.vkey` | Committee cold verification key  |
| `cc-cold.skey` | Committee cold signing key       |
| `cc-key.hash`  | Hashed cold verification key     |
| `cc.cert`      | Committee hot > cold certificate |


### Generate Committee member keys and certificate

Start your Committee registration by generating keys and a certificate.

```
# COLD: Generate Committee keys and certificate
scripts/govern.sh cc_cold_keys
scripts/govern.sh cc_cold_hash
scripts/govern.sh cc_hot_keys
scripts/govern.sh cc_cert

# COPY: copy the cc.cert to the producer
# PRODUCER: Build a transaction with the Committee certificate
scripts/tx.sh build 0 2 --certificate-file "/home/upstream/Cardano/cardano-node/keys/cc.cert"

# COPY: tx.raw to your cold node
# COLD: Sign the transaction
scripts/tx.sh sign --signing-key-file "/home/upstream/Cardano/cardano-node/keys/payment.skey" --signing-key-file "/home/upstream/Cardano/cardano-node/keys/cc-cold.skey"

# COPY: tx.signed to your producer node
# PRODUCER: Submit the transaction
scripts/tx.sh submit
```

---

## Registering a Midnight Validator

If you're running a block producing Stake Pool on the Preview network, you can opt to run as a Midnight validator.
When you have the midnight docker container installed and running (see above Midnight installation), you can run the
installation wizards (defined here in
the [midnight documentation](https://docs.midnight.network/validate/run-a-validator/step-3)):

```
# View wizard used for configurations once all partner services are up and running
./midnight-node.sh wizards --help

# Then you can start and restart containers
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml up -d
docker compose -f ./compose-partner-chains.yml -f ./compose.yml -f ./proof-server.yml restart

# If you need to edit postgres container files, e.g:
docker exec -it db-sync-postgres bash -c "echo 'host    all    all    172.22.0.0/16    scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf"
docker exec -it db-sync-postgres bash -c "echo 'host    all    all    172.2=5.0.0/16    scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf" 
```

### Validate your Midnight node keys

Once you have completed the registration steps and all services are operational, you can validate your node operations
and registration by querying the local rpc.

Query the services and search the results to ensure you are present, and the 'isValid' parameter is true.

```shell
# EPOCH_NUMBER = preview network registration epoch
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "sidechain_getAriadneParameters",
    "params": [<EPOCH_NUMBER>],
    "id": 1
}' http://127.0.0.1:9944 | jq
```

To confirm your Midnight Validator keys are configured correctly, query the author_hasKey for each key:

```shell
# Validate the sidechain_pub_key
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "author_hasKey",
    "params": ["<YOUR_KEY>", "crch"],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Validate the aura_pub_key
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "author_hasKey",
    "params": ["<YOUR_KEY>", "aura"],
    "id": 1
}' http://127.0.0.1:9944 | jq

# Validate the grandpa_pub_key
curl -L -X POST -H "Content-Type: application/json" -d '{
    "jsonrpc": "2.0",
    "method": "author_hasKey",
    "params": ["<YOUR_KEY>", "gran"],
    "id": 1
}' http://127.0.0.1:9944 | jq
```

### Monitoring Midnight node

Once running, you can monitor the midnight node using the docker logs and the community tool ./LiveView.sh linked above.

```
# Mannually enter the node shell
docker exec -it <CONTAINER_ID> bash

# Watch logs for each midnight service
docker logs -f --tail 100 cardano-ogmios
docker logs -f --tail 100 cardano-db-sync
docker logs -f --tail 100 db-sync-postgres
docker logs -f --tail 100 cardano-node
docker logs -f --tail 100 midnight-node

# LiveView tool is our recommended way to monitor your Midnight producer
./LiveView.sh
```

---

## BlockFrost Icebreaker

Installed on a Relay connected to your block producing SPOs topology.

```shell
# RELAY: Download BlockFrost and init
scripts/node/icebreaker.sh download

# RELAY: Install BlockFrost service and start
scripts/node/icebreaker.sh install

# Check installed version
blockfrost-platform --version
```

When running, you can monitor the processes:

```shell
scripts/node/icebreaker.sh watch
scripts/node/icebreaker.sh status
```

You can review icebreaker status using the BlockFrost UI:

- [https://blockfrost.grafana.net/public-dashboards/8d618eda298d472a996ca3473ab36177](https://blockfrost.grafana.net/public-dashboards/8d618eda298d472a996ca3473ab36177)
- [https://platform.blockfrost.io/verification](https://platform.blockfrost.io/verification)

---

## Repository info

### Script notation

- `( )` Parenthesis = mandatory parameters.
- `[ ]` Square brackets = optional parameters.
- `< >` Angle brackets = parameter types.
- `|` Bar = Choice between several options.

```
Usage: query.sh (
  tip [name <STRING>] |
  params [name <STRING<'option1'|'option2'>>] |
  config (name <STRING>) [key <STRING>] |
)
```

### Contributors

- Upstream SPO - [@upstream_ada](https://x.com/Upstream_ada)
- Devhalls - [@devhalls](https://github.com/devhalls)

### Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any
contributions you make are greatly appreciated.

If you have a suggestion that would make this plugin better, please fork the repo and create a pull request. You can
also simply open an issue with the tag "enhancement". Don't forget to give the project a star! Thanks again!

1. Fork the Project
2. Create your Feature Branch (git checkout -b feature/AmazingFeature)
3. Commit your Changes (git commit -m 'Add some AmazingFeature')
4. Push to the Branch (git push origin feature/AmazingFeature)
5. Open a Pull Request [#BuildingTogether](https://x.com/search?q=buildingtogether)

### License

Distributed under the GPL-3.0 License. See LICENSE.txt for more information.

### Links

- [Cardano testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet/)
- [Db-sync snapshots](https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html)
- [Upstream SPO website](https://upstream.org.uk)
- [Upstream Twitter](https://x.com/Upstream_ada)
- [Upstream Cardano Monitor Scripts](https://github.com/devhalls/spo-operational-scripts)
- [Midnight Monitoring - LiveView](https://github.com/Midnight-Scripts/Midnight-Live-View/blob/main/LiveView.sh)
- [Cardano Node Guild Operators LiveView](https://cardano-community.github.io/guild-operators/Scripts/gliveview/)

