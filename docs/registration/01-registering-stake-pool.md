# Registering a Stake Pool

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](../deployment/01-cardano-node-installation.md)
2. [Mithril Node installation](../deployment/02-mithril-installation.md)
3. [Cardano DBSync installation](../deployment/03-cardano-dbsync-installation.md)
4. [Midnight Node installation](../deployment/04-midnight-installation.md)
5. [Midnight DBSync installation](../deployment/05-midnight-dbsync-installation.md)
6. [Local Docker](../deployment/06-docker-installation.md)

**Registration**
1. **Registering a Stake Pool**
2. [Managing a Stake Pool](02-managing-stake-pool.md)
3. [Registering a DRep](03-registering-drep.md)
4. [Registering a Constitutional Committee member](04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](06-registering-midnight-validator.md)

---

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
# EXTERNAL: Fund your payment address (see the [testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet/) in [README — Links](../README.md#links))
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

