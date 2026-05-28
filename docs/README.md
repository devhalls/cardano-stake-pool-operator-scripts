# Documentation

Manage your Cardano nodes using easy to understand environment managemnt

---

## Getting started

We divide our workflow in two main branches; **deployment**, covering node dependencies, configs and installs, and
**registrations**, covering stake pool, mithril, midnight, and other services requiring certificates.

**Deployment**

1. [Cardano Node installation](docs/cardano-node-installation.md)
2. [Mithril Node installation](docs/mithril-installation.md)
3. [Cardano DBSync installation](docs/cardano-dbsync-installation.md)
4. [Midnight Node installation](docs/midnight-installation.md)
5. [Midnight DBSync installation](docs/midnight-dbsync-installation.md)
6. [Local Docker](docs/docker-installation.md)

**Registrations**

1. [Registering a Stake Pool](docs/registering-stake-pool.md)
2. [Managing a Stake Pool](docs/managing-stake-pool.md)
3. [Registering a DRep](docs/registering-drep.md)
4. [Registering a Constitutional Committee member](docs/registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](docs/blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](docs/registering-midnight-validator.md)

**Tests**

1. [Integration and smoke tests](TESTS.md)

---

## Script notation

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