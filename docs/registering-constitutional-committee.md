# Registering a Constitutional Committee member

[README](../README.md)

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

