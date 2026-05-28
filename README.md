# Cardano Stake Pool Operator (SPO) scripts

Scripts and procedures for installing and managing a Cardano node, Mithril node, Midnight node, and operating
credentials for a Stake Pool, DRep or Constitutional Committee member.

[![Upstream][Upstream-shield]][Upstream-url]
[![Cardano][Cardano-shield]][Cardano-url]
[![Midnight][Midnight-shield]][Midnight-url]
[![Mithril][Mithril-shield]][Mithril-url]
[![DBSync][DBSync-shield]][DBSync-url]

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

---

## Links

- [Cardano testnet faucet](https://docs.cardano.org/cardano-testnets/tools/faucet/)
- [Db-sync snapshots](https://update-cardano-mainnet.iohk.io/cardano-db-sync/index.html)
- [Upstream SPO website](https://upstream.org.uk)
- [Upstream Twitter](https://x.com/Upstream_ada)
- [Upstream Cardano Monitor Scripts](https://github.com/devhalls/spo-operational-scripts)
- [Midnight Monitoring - LiveView](https://github.com/Midnight-Scripts/Midnight-Live-View/blob/main/LiveView.sh)
- [Cardano Node Guild Operators LiveView](https://cardano-community.github.io/guild-operators/Scripts/gliveview/)


[Cardano-shield]: https://img.shields.io/badge/cardano-000000?style=for-the-badge&logo=cardano

[Cardano-url]: https://cardano.org/

[Mithril-shield]: https://img.shields.io/badge/mithril-000000?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyBpZD0iTGF5ZXJfMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB2aWV3Qm94PSIwIDAgNjguOCA2OC44MiI+PGRlZnM+PHN0eWxlPi5jbHMtMXtmaWxsOiNmZmY7fTwvc3R5bGU+PC9kZWZzPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTM0LjQxLDM5LjA4cy01LjA1LDExLjc5LTE0LjQ2LDE3LjFjMy45OCw0LjM0LDguNzQsOC42MSwxNC40NiwxMi42NCw1LjcyLTQuMDMsMTAuNDgtOC4zLDE0LjQ2LTEyLjY0LTkuNDEtNS4zMS0xNC40Ni0xNy4xLTE0LjQ2LTE3LjFaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMzQuNDEsMTIuNzljLTQuNTgsOS45LTE3LjI0LDE2Ljg1LTI5LjI5LDIwLjA0LDIuMTcsNS4zOCw1LjI2LDExLjIxLDkuNjUsMTcuMDhsMi45LTguNTFjNi42My0zLjk1LDEzLjc0LTguMzIsMTYuNzUtMTQuODQsMy4wMSw2LjUyLDEwLjEyLDEwLjg5LDE2Ljc1LDE0Ljg0bDIuODksOC41MWM0LjM4LTUuODcsNy40Ny0xMS43LDkuNjUtMTcuMDgtMTIuMDUtMy4xOS0yNC43MS0xMC4xNC0yOS4yOS0yMC4wNGgtLjAxWiIvPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTY4LjgsNy44MVM1My4zMywwLDM0LjQxLDAsLjAyLDcuODEuMDIsNy44MUMuMDIsNy44MS0uNDEsMTUuNjcsMi45MywyNi42N2w1LjYzLTguODhjMTAuMzgtMi45OSwyMC43OC03LjMzLDI1Ljg0LTE1LjE3LDUuMDYsNy44NCwxNS40NiwxMi4xOCwyNS44NCwxNS4xN2w1LjYzLDguODhjMy4zNC0xMC45OSwyLjkxLTE4Ljg2LDIuOTEtMTguODZoLjAyWiIvPjwvc3ZnPg==

[Mithril-url]: https://mithril.network/

[Midnight-shield]: https://img.shields.io/badge/midnight-000000?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyBpZD0iTGF5ZXJfMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB2aWV3Qm94PSIwIDAgMjY2Ljg2IDI2Ni44NiI+PGRlZnM+PHN0eWxlPi5jbHMtMXtmaWxsOiNmZmY7fTwvc3R5bGU+PC9kZWZzPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTEzMy40MywwQzU5LjcsMCwwLDU5LjgxLDAsMTMzLjQzczU5LjgxLDEzMy40MywxMzMuNDMsMTMzLjQzLDEzMy40My01OS44MSwxMzMuNDMtMTMzLjQzUzIwNy4xNiwwLDEzMy40MywwWk0xMzMuNDMsMjQyLjMyYy02MC4wMiwwLTEwOC44OS00OC44Ny0xMDguODktMTA4Ljg5UzczLjQxLDI0LjU0LDEzMy40MywyNC41NHMxMDguODksNDguODcsMTA4Ljg5LDEwOC44OS00OC44NywxMDguODktMTA4Ljg5LDEwOC44OWgwWiIvPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTE0NS45NywxMjAuODloLTI1LjA3djI1LjA3aDI1LjA3di0yNS4wN1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0xNDUuOTcsODEuMzhoLTI1LjA3djI1LjA3aDI1LjA3di0yNS4wN1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0xNDUuOTcsNDEuNzVoLTI1LjA3djI1LjA3aDI1LjA3di0yNS4wN1oiLz48L3N2Zz4=

[Midnight-url]: https://midnight.network/

[Upstream-shield]: https://img.shields.io/badge/upstream-000000?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyBpZD0iTGF5ZXJfMSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIiB2aWV3Qm94PSIwIDAgNTcuMjMgNTcuMjMiPjxkZWZzPjxzdHlsZT4uY2xzLTF7ZmlsbDojZmZmO308L3N0eWxlPjwvZGVmcz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0yOC42MS4yNUMxMi45NS4yNS4yNSwxMi45NS4yNSwyOC42MXMxMi43LDI4LjM3LDI4LjM2LDI4LjM3LDI4LjM3LTEyLjcsMjguMzctMjguMzdTNDQuMjguMjUsMjguNjEuMjVaTTE1LjIzLDM5Ljc5YzAtLjc5LjA3LTEuNi4yMS0yLjM3aC0uMDFzMC0uMDcuMDItLjA5Yy4yMS0uNjUuNDgtMS4xNi43OS0xLjU1LjM0LS40LjcyLS42NiwxLjE4LS43OS43Ni0uMjEsMS42MiwwLDIuNjcuNTkuOTQuNTUsMS45NiwxLjM5LDIuNzMsMi4wNy4zMy4yOC42NS41OC45Ny44Ni4wNCwwLC4wOS4wMi4xNS4wNS4yNi4wOC41LjE1Ljc1LjIyLDEuNTUuNDEsMy4xOS4zOCw0LjczLS4wNi45Ni0uMjgsMS44NC0uNywyLjc5LTEuMTUuNS0uMjUsMS4wMy0uNDksMS41NS0uNzEsMS45Ni0uODMsMy42MS0xLjA0LDUuMDUtLjY1LDEuMzkuMzcsMi45MiwxLjY2LDMuMTUsMy4zMi4wNC4wOC4wNi4xNi4wNi4yNiwwLDEuODEtLjM1LDMuNTYtMS4wNSw1LjIxLS42OCwxLjYtMS42NCwzLjAzLTIuODcsNC4yNS0xLjIyLDEuMjItMi42NiwyLjE5LTQuMjUsMi44Ny0xLjY2LjctMy40LDEuMDUtNS4yMSwxLjA1cy0zLjU3LS4zNS01LjIyLTEuMDVjLTEuNi0uNjgtMy4wMy0xLjY0LTQuMjUtMi44N3MtMi4yLTIuNjctMi44Ny00LjI1Yy0uNy0xLjY2LTEuMDUtMy40LTEuMDUtNS4yMVpNMTguMzgsMjkuNzNjMC0uOTYuMjYtMS41Ni40NC0ydi4wMmMuMDUtLjA4LjA5LS4xNy4xMi0uMjYuMDQtLjA4LjA3LS4xNi4wOS0uMjYuMDktLjI1LjE5LS41Mi4zMS0uNzhMMjguMDcsMy4yOGMuMDgtLjIyLjMtLjM3LjU0LS4zN3MuNDUuMTUuNTQuMzdsOS42OSwyNS42OSwxLjEyLDIuOTZzLjAxLjA2LjAyLjA4Yy4xNi43OC0uMTUsMS4yNy0uNDQsMS41NS0uNTIuNTEtMS40My43Ni0yLjc3Ljc2aC0uMzljLTEuMjYtLjA1LTIuODItLjI4LTQuNjUtLjcxbC0xLjUuNDljLTEuMzMuNDMtMi42OS44Ny00LjE2Ljk1aC0uMzRjLTIuNiwwLTUuMTUtMS4yOS02LjU4LTMuMzQtLjMzLS40Ny0uNzYtMS4xNy0uNzYtMS45N1oiLz48cGF0aCBjbGFzcz0iY2xzLTEiIGQ9Ik0xOS41NywyOS43N2MwLC4xNS4wMi4zNi4xNy42OWgtLjAyYy4wOC4xNi4xOS4zNi4zNi42MS42Mi44OSwxLjUyLDEuNjMsMi41OCwyLjE1LDEuMDYuNTEsMi4yMy43NiwzLjM3LjcsMS4wNi0uMDUsMi4xMS0uMzMsMy4xNS0uNjUuMTYtLjA1LjM0LS4xLjUtLjE2aC4wMnMtLjA1LDAtLjA3LS4wMmMtLjg4LS4yNy0xLjcxLS41Ny0yLjUyLS45OC0xLjE4LS42MS0yLjMzLTEuNDMtMy43My0yLjY5bC0uMDYtLjA2Yy0uNDItLjM3LS44NC0uNzYtMS4yNS0xLjEyLS4zMi0uMjctLjY4LS41Ny0xLjAzLS43OC0uNDgtLjMtLjY2LS4yNy0uNjktLjI2LS4wNCwwLS4wNy4wOC0uMTEuMTgtLjAyLjA2LS4wNS4xLS4wOC4xNS0uMDEuMDUtLjAzLjA5LS4wNS4xNC0uMDMuMDgtLjA3LjE3LS4wOS4yNy0uMDQuMDktLjA4LjItLjEyLjI5LS4xNy40MS0uMzUuODMtLjM1LDEuNTZaIi8+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMjUuNjUsNDAuMTFjLjczLjU5LDEuMzUsMS4wMSwxLjk1LDEuMzQsMS4wMy41NywyLjA2LjksMy40NSwxLjA5LDMuNjkuNTUsNS45OC4yNSw3LjM4LS4zLjU4LS4yMiwxLjAxLS40OSwxLjMzLS43NS4yMy0uMTkuNDEtLjM4LjU1LS41Ny4wMi0uMDIuMDUtLjA2LjA3LS4wOC4yNi0uMzUuMzYtLjY4LjQyLS44N3YtLjIzbC4wMy4wMmMwLS4xMy0uMDMtLjI2LS4wOC0uNC0uMTItLjM4LS4zNi0uNzgtLjctMS4xMy0uNDMtLjQ0LS45OS0uNzgtMS41NS0uOTMtLjA2LS4wMS0uMTMtLjAyLS4xOS0uMDMtLjE2LS4wNC0uMzMtLjA3LS40OS0uMDgtLjI2LS4wMi0uNTItLjA0LS44Mi0uMDFoLS4zYy0uMDYsMC0uMTIuMDEtLjE3LjAyLS4wMywwLS4wOCwwLS4xMi4wMS0uMDcsMC0uMTQuMDItLjIxLjA0LS4xMi4wMi0uMjIuMDUtLjM1LjA3LS4xMy4wMy0uMjYuMDctLjQuMS0uMjcuMDgtLjU1LjE3LS44My4yOC0uMTQuMDYtLjI5LjEtLjQzLjE3LS41LjIxLTEuMDEuNDUtMS41LjctLjk0LjQ1LTEuOTIuOTItMi45NywxLjIzLTEuMzMuMzgtMi43LjQ5LTQuMDcuMzFaIi8+PC9zdmc+

[Upstream-url]: https://upstream.org.uk/

[DBSync-shield]: https://img.shields.io/badge/dbsync-000000?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyBpZD0iSWNvbnMiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgdmlld0JveD0iMCAwIDIyIDI4Ij48ZGVmcz48c3R5bGU+LmNscy0xe2ZpbGw6I2ZmZjt9PC9zdHlsZT48L2RlZnM+PHBhdGggY2xhc3M9ImNscy0xIiBkPSJNMCwxMC40djMuNmMwLDMuNCw0LjgsNiwxMSw2czExLTIuNiwxMS02di0zLjZjLTIuMiwyLjItNi4yLDMuNi0xMSwzLjZTMi4yLDEyLjYsMCwxMC40WiIvPjxwYXRoIGNsYXNzPSJjbHMtMSIgZD0iTTAsMTguNHYzLjZjMCwzLjQsNC44LDYsMTEsNnMxMS0yLjYsMTEtNnYtMy42Yy0yLjIsMi4yLTYuMiwzLjYtMTEsMy42cy04LjgtMS40LTExLTMuNloiLz48ZWxsaXBzZSBjbGFzcz0iY2xzLTEiIGN4PSIxMSIgY3k9IjYiIHJ4PSIxMSIgcnk9IjYiLz48L3N2Zz4=

[DBSync-url]: https://github.com/IntersectMBO/cardano-db-sync/
