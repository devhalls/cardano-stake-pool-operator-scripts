# Protocol parameters for Cardano Connect API

[Full docs index](../README.md) · [Cardano Connect API protocol-params](https://github.com/pendulumdev/cardano-connect-api/blob/develop/docs/protocol-params.md)

When **cardano-connect-api** runs on a different host than your node, the API pulls **`params.json`** over SSH/rsync. This host generates that file from the local socket.

## File location

| Item | Path |
|------|------|
| Generated JSON | **`$NETWORK_PATH/params.json`** |
| Same as | `scripts/query.sh params` (Conway `protocol-parameters`) |

With default `env` (`NETWORK_PATH=$NODE_HOME/cardano-node`), mainnet example:

```text
/home/upstream/Cardano/cardano-node/params.json
```

Set **`PROTOCOL_PARAMS_REMOTE_PATH_MAINNET`** on the API to this path.

## Generate on a schedule (this host)

Use the cron wrapper (warm relay or producer only):

```shell
# Once, verify manually:
scripts/cron-protocol-params.sh

# Crontab (NODE_USER) — hourly at :10; API typically pulls at :15
crontab -e
```

```cron
10 * * * * /home/upstream/Cardano/scripts/cron-protocol-params.sh >> /home/upstream/Cardano/cardano-node/logs/crontab.log 2>&1
```

Adjust `/home/upstream/Cardano` to your `NODE_HOME` / repo checkout.

## API host requirements

On the **API** machine (not here):

- `PROTOCOL_PARAMS_DRIVER=file`
- `PROTOCOL_PARAMS_REMOTE_HOST` = this server’s LAN IP
- `PROTOCOL_PARAMS_REMOTE_USER` = Unix user that owns `params.json` (often `$NODE_USER`)
- SSH key from API deploy user → this host (read-only access to `params.json` is enough)

The API job **`SyncProtocolParams`** runs hourly and rsyncs into  
`api/storage/app/{network}/query/params.json`.

## Manual refresh

```shell
scripts/query.sh params
# or
scripts/cron-protocol-params.sh
```
