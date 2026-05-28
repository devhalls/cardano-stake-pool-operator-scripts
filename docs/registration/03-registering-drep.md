# Registering a DRep

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
3. **Registering a DRep**
4. [Registering a Constitutional Committee member](04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](06-registering-midnight-validator.md)

---

To register as a DRep you must have a running **fully synced** node. We can then generate the following assets:

DRep assets


|             |                       |
| ----------- | --------------------- |
| `drep.vkey` | DRep verification key |
| `drep.skey` | DRep signing key      |
| `drep.cert` | DRep certificate      |
| `drep.dereg`| DRep de-registration certificate |
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

### De-registering a DRep

De-registration returns your DRep deposit to your payment address.

```shell
# PRODUCER: confirm DRep is registered
scripts/govern.sh drep_state

# COLD: generate de-registration certificate ($DREP_DREG_CERT)
scripts/govern.sh drep_dreg_cert

# COPY: drep.dereg to your producer node
# PRODUCER: build a tx with the de-registration certificate
scripts/tx.sh drep_dereg_raw

# COPY: tx.raw to your cold node
# COLD: sign the transaction
scripts/tx.sh drep_dereg_sign

# COPY: tx.signed to your producer node
# PRODUCER: submit the transaction
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

