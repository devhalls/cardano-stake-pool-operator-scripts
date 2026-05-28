# Registering a DRep

[README](../README.md)

---

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

