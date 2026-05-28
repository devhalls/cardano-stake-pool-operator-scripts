# Managing a Stake Pool

[README](../README.md)

---

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

