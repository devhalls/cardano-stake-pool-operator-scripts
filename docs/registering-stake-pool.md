# Registering a Stake Pool

[README](../README.md)

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

### Configure topology and restart the producer

Set pool topology in `env` (not by hand-editing `topology.json`). On the **producer**, list your relays; on each
**relay**, set the block producer address. Then sync configs and restart:

```shell
# PRODUCER: set relay host:port list in env
nano env   # NODE_TOPOLOGY_RELAY_HOSTS=relay1:6000,relay2:6000

# PRODUCER: render topology from env and sync other configs
scripts/node.sh install configs

# PRODUCER: set NODE_TYPE=producer if not already
nano env

# PRODUCER: restart
scripts/node.sh restart
```

On relays, set `NODE_TOPOLOGY_BP_HOST=producer-ip:6000` and run `scripts/node.sh install configs` before restart.
Leave `NODE_TOPOLOGY_*` empty on a standalone relay or producer to keep the bundled public/bootstrap topology.

---

