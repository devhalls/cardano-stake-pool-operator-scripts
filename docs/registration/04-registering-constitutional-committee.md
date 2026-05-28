# Registering a Constitutional Committee member

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](../deployment/01-cardano-node-installation.md)
2. [Mithril Node installation](../deployment/02-mithril-installation.md)
3. [Cardano DBSync installation](../deployment/03-cardano-dbsync-installation.md)
4. [Midnight Node installation](../deployment/04-midnight-installation.md)
5. [Midnight DBSync installation](../deployment/05-midnight-dbsync-installation.md)
6. [Local Docker](../deployment/06-docker-installation.md)

**Registration**
1. [Registering a Stake Pool](01-registering-stake-pool.md)
2. [Managing a Stake Pool](02-managing-stake-pool.md)
3. [Registering a DRep](03-registering-drep.md)
4. **Registering a Constitutional Committee member**
5. [BlockFrost Icebreaker](05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](06-registering-midnight-validator.md)

---

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

