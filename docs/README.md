# Documentation

**Full docs index** · [Integration and smoke tests](TESTS.md) · [AI / agent guide](../AGENTS.md)

**Deployment**
1. [Cardano Node installation](deployment/01-cardano-node-installation.md)
2. [Mithril Node installation](deployment/02-mithril-installation.md)
3. [Cardano DBSync installation](deployment/03-cardano-dbsync-installation.md)
4. [Midnight Node installation](deployment/04-midnight-installation.md)
5. [Midnight DBSync installation](deployment/05-midnight-dbsync-installation.md)
6. [Local Docker](deployment/06-docker-installation.md)

**Registration**
1. [Registering a Stake Pool](registration/01-registering-stake-pool.md)
2. [Managing a Stake Pool](registration/02-managing-stake-pool.md)
3. [Registering a DRep](registration/03-registering-drep.md)
4. [Registering a Constitutional Committee member](registration/04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](registration/05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](registration/06-registering-midnight-validator.md)

---

Operate Cardano nodes using easy to understand environment configurations. We divide our workflow in two branches; **deployment**, covering node dependencies, configs and installs, and **registration**, covering stake pool, DRep, mithril, midnight, and other services requiring operational certificates.

## Folder structure

```
docs/
├── README.md
├── TESTS.md
├── deployment/
│   ├── 01-cardano-node-installation.md
│   ├── 02-mithril-installation.md
│   ├── 03-cardano-dbsync-installation.md
│   ├── 04-midnight-installation.md
│   ├── 05-midnight-dbsync-installation.md
│   └── 06-docker-installation.md
└── registration/
    ├── 01-registering-stake-pool.md
    ├── 02-managing-stake-pool.md
    ├── 03-registering-drep.md
    ├── 04-registering-constitutional-committee.md
    ├── 05-blockfrost-icebreaker.md
    └── 06-registering-midnight-validator.md
```

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
