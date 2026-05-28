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

<details>
<summary><strong>Repository file tree</strong></summary>

```
tree --filesfirst -L 3

├── LICENSE
├── README.md
├── docs
│   ├── TESTS.md
│   ├── cardano-node-installation.md
│   ├── mithril-installation.md
│   ├── cardano-dbsync-installation.md
│   ├── midnight-installation.md
│   ├── midnight-dbsync-installation.md
│   ├── docker-installation.md
│   ├── registering-stake-pool.md
│   ├── managing-stake-pool.md
│   ├── registering-drep.md
│   ├── registering-constitutional-committee.md
│   ├── blockfrost-icebreaker.md
│   └── registering-midnight-validator.md
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

</details>

<details>
<summary><strong>Assumptions</strong></summary>

1. Your OS, LAN network, ports, and user are already configured.
2. The Ngrok script requires you to know how to set up your own ngrok account and endpoints.
3. You are comfortable with cardano-node / cardano-cli and general SPO requirements.
4. You are comfortable with Linux and managing networks and servers.
5. You are able to set up your cold node by copying the binaries, scripts, and keys securely as required.

</details>

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

**Documentation**

- [Full docs index](docs/README.md)
- [Integration and smoke tests](docs/TESTS.md)
- [AI / agent guide](AGENTS.md) (for Cursor, Copilot, and other assistants)

---

## Contributors

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

