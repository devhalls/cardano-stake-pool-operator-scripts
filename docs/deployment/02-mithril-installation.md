# Mithril Node installation

[Full docs index](../README.md) · [Integration and smoke tests](../TESTS.md) · [AI / agent guide](../../AGENTS.md)

**Deployment**
1. [Cardano Node installation](01-cardano-node-installation.md)
2. **Mithril Node installation**
3. [Cardano DBSync installation](03-cardano-dbsync-installation.md)
4. [Midnight Node installation](04-midnight-installation.md)
5. [Midnight DBSync installation](05-midnight-dbsync-installation.md)
6. [Local Docker](06-docker-installation.md)

**Registration**
1. [Registering a Stake Pool](../registration/01-registering-stake-pool.md)
2. [Managing a Stake Pool](../registration/02-managing-stake-pool.md)
3. [Registering a DRep](../registration/03-registering-drep.md)
4. [Registering a Constitutional Committee member](../registration/04-registering-constitutional-committee.md)
5. [BlockFrost Icebreaker](../registration/05-blockfrost-icebreaker.md)
6. [Registering a Midnight Validator](../registration/06-registering-midnight-validator.md)

---

To operate as a mithril signer, you must have a synced block producer and relay. Mithril signers must operate using a
sentry architecture, where a mithril relay connects to the wider network and the mithril signer connects to the relay.
However, on testnets we operate the Mithril signer directly and do not install a relay.

### Mithril signer

```shell
# Check compatability with your nodes version
scripts/node.sh mithril check_compatability

# Edit the MITHRIL_VERSION in your env file, then update
nano env
scripts/node.sh mithril update

# Install the signer env and service
scripts/node.sh mithril install_signer_env
scripts/node.sh mithril install_signer_service
```

### Mithril update

When you would like to update mithril, edit `MITHRIL_VERSION` in your env file and run the update script.

```shell
nano env
scripts/node.sh mithril update
```

### Mithril relay

```shell
scripts/node.sh mithril install_squid
scripts/node.sh mithril configure_squid
```

