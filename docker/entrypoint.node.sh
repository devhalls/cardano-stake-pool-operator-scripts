#!/bin/bash
set -e

echo "[ENTRYPOINT] Start container setup"
echo "[ENTRYPOINT] Copy env.docker > env"
cp $NODE_HOME/env.docker $NODE_HOME/env
source $NODE_HOME/env

_node_version_ok() {
    command -v "$CNNODE" >/dev/null 2>&1 \
        && "$CNNODE" version 2>/dev/null | head -1 | grep -qF "$NODE_VERSION"
}

if ! command -v $CNNODE >/dev/null 2>&1; then
    echo "[ENTRYPOINT] Installing"
    $NODE_HOME/scripts/node.sh install
    if [ -n "$MITHRIL_VERSION" ] && [ -n "$MITHRIL_AGGREGATOR_ENDPOINT" ]; then
        echo "[ENTRYPOINT] Installing mithril"
        $NODE_HOME/scripts/node.sh mithril download
        $NODE_HOME/scripts/node.sh mithril sync
    elif [ -n "$MITHRIL_VERSION" ]; then
        echo "[ENTRYPOINT] Skipping mithril sync, network $NODE_NETWORK is not supported"
    fi
elif ! _node_version_ok; then
    echo "[ENTRYPOINT] Node binary is not $NODE_VERSION — installing binaries"
    $NODE_HOME/scripts/node/install.sh dependencies
    $NODE_HOME/scripts/node/install.sh binaries
    if [ ! -f "$NETWORK_PATH/config.json" ]; then
        $NODE_HOME/scripts/node/install.sh configs
    fi
elif [ ! -f "$NETWORK_PATH/config.json" ]; then
    echo "[ENTRYPOINT] Binaries present but configs missing — installing configs for $NODE_NETWORK"
    $NODE_HOME/scripts/node/install.sh dependencies
    $NODE_HOME/scripts/node/install.sh configs
else
    echo "[ENTRYPOINT] Skipping install"
fi

echo "[ENTRYPOINT] Open metric endpoints"
if [[ -f "$NODE_HOME/cardano-node/config.json" ]]; then
    sed -i $NODE_HOME/cardano-node/config.json -e "s/127.0.0.1/0.0.0.0/g"
fi
if [[ -f "$NODE_HOME/cardano-node/config-bp.json" ]]; then
    sed -i $NODE_HOME/cardano-node/config-bp.json -e "s/127.0.0.1/0.0.0.0/g"
fi

echo "[ENTRYPOINT] Starting node_exporter"
nohup node_exporter --web.listen-address=":9100" &

legacy_socket="$NETWORK_DB_PATH/socket"
if [[ -S "$legacy_socket" && "$legacy_socket" != "$NETWORK_SOCKET_PATH" ]]; then
    echo "[ENTRYPOINT] Removing legacy bind-mounted socket at $legacy_socket"
    rm -f "$legacy_socket" 2>/dev/null || true
fi
if [[ -S "$NETWORK_SOCKET_PATH" ]]; then
    echo "[ENTRYPOINT] Removing stale socket at $NETWORK_SOCKET_PATH"
    rm -f "$NETWORK_SOCKET_PATH"
fi

echo "[ENTRYPOINT] Starting node"
$NODE_HOME/scripts/node.sh run
