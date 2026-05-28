# Mithril Node installation

[README](../README.md)

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

