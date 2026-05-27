#!/bin/bash
# Usage: node/mithril.sh (
#   update |
#   target |
#   current |
#   check |
#   download |
#   sync |
#   check_compatability |
#   install_signer_env |
#   install_signer_service |
#   install_squid |
#   configure_squid |
#   start |
#   stop |
#   restart |
#   watch |
#   status |
#   start_squid |
#   stop_squid |
#   restart_squid |
#   watch_squid |
#   status_squid |
#   verify_registration |
#   verify_signature |
#   help [-h]
# )
#
# Info:
#
#   - update) Updates mithril to $MITHRIL_VERSION.
#   - target) Get the target mithril version from the env file.
#   - current) Get the current mithril version.
#   - check) Check if there is an update available from the current version.
#   - download) Download the mithril binaries.
#   - sync) Sync your node using the Mithril client.
#   - check_compatability) Checks if $NODE_VERSION is compatible as a mithril signer.
#   - install_signer_env) Installs the mithril signer env.
#   - install_signer_service) Installs the mithril signer service.
#   - install_squid) Installs the squid proxy server.
#   - configure_squid) Configures the squid server.
#   - start) Starts the mithril signer service.
#   - stop) Stops the mithril signer service.
#   - restart) Restarts the mithril signer service.
#   - watch) Watch mithril signer service logs.
#   - status) Display mithril signer service status.
#   - start_squid) Starts the squid service.
#   - stop_squid) Stops the squid service.
#   - restart_squid) Restarts the squid service.
#   - watch_squid) Watch squid service logs.
#   - status_squid) Display squid service status.
#   - verify_registration) Verify that your signer is registered.
#   - verify_signature) Verify that your signer contributes with individual signatures.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../common.sh"

# Private functions

_mithril_die() {
    print 'ERROR' "$1" $red
    return 1
}

_mithril_fail() {
    _mithril_die "$1" || return 1
}

_require_warm_node() {
    if is_cold_device; then
        _mithril_fail 'This command can not be run on a cold device'
    fi
}

_require_producer_node() {
    if is_not_producer_device; then
        _mithril_fail 'This command can only be run on a producer device'
    fi
}

_require_relay_node() {
    if is_not_relay_device; then
        _mithril_fail 'This command can only be run on a relay device'
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _mithril_fail 'Mithril update cancelled' ;;
    esac
}

_extract_mithril_release() {
    local filename="$1"
    local extract_dir="downloads/extract"

    remove_path "$extract_dir"
    mkdir -p "$extract_dir" || _mithril_fail 'Could not create extract directory' || return 1
    tar -xvzf "downloads/$filename" -C "$extract_dir" || _mithril_fail "Could not extract archive: $filename" || return 1
    cp -a "$extract_dir/." "$BIN_PATH/" || _mithril_fail 'Could not copy mithril binaries to bin path' || return 1
    return 0
}

# Public functions

mithril_download() {
    _require_warm_node || return 1
    print 'MITHRIL' "Downloading mithril binaries"
    local filenames=($(mithril_release_filenames)) || _mithril_fail "Unsupported platform: $(platform)" || return 1
    local filename

    if download_release_file "$MITHRIL_REMOTE" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        _extract_mithril_release "$filename" || return 1
        chmod +x -R "$BIN_PATH" || _mithril_fail 'Could not set bin path permissions' || return 1
        remove_path downloads
        mkdir -p "$MITHRIL_PATH" || _mithril_fail 'Could not create mithril path' || return 1
        echo "$MITHRIL_VERSION" > "$MITHRIL_PATH/version" || _mithril_fail 'Could not write mithril version file' || return 1
        $MITHRIL_CLIENT --version || _mithril_fail 'Downloaded mithril-client binary is not runnable' || return 1
        $MITHRIL_SIGNER --version || _mithril_fail 'Downloaded mithril-signer binary is not runnable' || return 1
        print 'DOWNLOAD' "Mithril binaries moved to $BIN_PATH" $green
        return 0
    fi

    remove_path downloads
    _mithril_fail "Unable to download mithril binaries for $(platform)/$(platform_arch)" || return 1
}

mithril_sync() {
    _require_warm_node || return 1
    print 'MITHRIL' "Syncing db via mithril"
    export AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
    if [[ $NODE_NETWORK == 'preprod' ]]; then
        export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/genesis.vkey)
    elif [[ $NODE_NETWORK == 'preview' ]]; then
        export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/genesis.vkey)
    elif [[ $NODE_NETWORK == 'mainnet' ]]; then
        export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/genesis.vkey)
    else
        _mithril_fail "$NODE_NETWORK is not supported by mithril sync" || return 1
    fi
    export NETWORK=$NODE_NETWORK

    $MITHRIL_CLIENT cardano-db download --download-dir "$NETWORK_PATH" latest || _mithril_fail 'Unable to sync with mithril' || return 1
    print 'MITHRIL' "DB synced via mithril, please restart your node" $green
    return 0
}

mithril_check_compatability() {
    _require_producer_node || return 1
    print 'MITHRIL' 'Min node version:'
    wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/networks.json |
        jq -r ".\"$NODE_NETWORK\".\"cardano-minimum-version\".\"mithril-signer\""
    return 0
}

mithril_update_target_version() {
    echo $MITHRIL_VERSION
    return 0
}

mithril_update_current_version() {
    if [ -f "$MITHRIL_PATH/version" ]; then
        cat "$MITHRIL_PATH/version"
    else
        echo ""
    fi
    return 0
}

mithril_update_check_version() {
    local latest current
    latest=$(mithril_update_target_version)
    current=$(mithril_update_current_version)
    if [ "$current" == "$latest" ]; then
        print 'UPDATE' "Mithril is already up to date (v$current)" $green
        return 1
    elif [ -z "$current" ] || [ -z "$latest" ]; then
        _mithril_fail "Unable to read update versions [current:$current] [latest:$latest]" || return 1
    else
        echo $latest
        return 0
    fi
}

mithril_update() {
    _require_producer_node || return 1
    local latest
    latest=$(mithril_update_check_version) || return 1
    _confirm "Please confirm mithril update to version: $latest?" || return 1
    mithril_stop || return 1
    mithril_download || return 1
    mithril_restart || return 1
    $MITHRIL_CLIENT --version || _mithril_fail 'Installed mithril-client binary is not runnable' || return 1
    $MITHRIL_SIGNER --version || _mithril_fail 'Installed mithril-signer binary is not runnable' || return 1
    print 'UPDATE' "Mithril updated and restarted" $green
    return 0
}

mithril_install_signer_env() {
    _require_producer_node || return 1
    mkdir -p "$MITHRIL_PATH" || _mithril_fail 'Could not create mithril path' || return 1
    rm "$MITHRIL_PATH/mithril-signer.env"

    wget -O "$MITHRIL_PATH/verify_signer_registration.sh" https://mithril.network/doc/scripts/verify_signer_registration.sh || \
        _mithril_fail 'Could not download verify_signer_registration.sh' || return 1
    chmod +x "$MITHRIL_PATH/verify_signer_registration.sh" || _mithril_fail 'Could not set verify_signer_registration.sh permissions' || return 1
    wget -O "$MITHRIL_PATH/verify_signer_signature.sh" https://mithril.network/doc/scripts/verify_signer_signature.sh || \
        _mithril_fail 'Could not download verify_signer_signature.sh' || return 1
    chmod +x "$MITHRIL_PATH/verify_signer_signature.sh" || _mithril_fail 'Could not set verify_signer_signature.sh permissions' || return 1

    printf "KES_SECRET_KEY_PATH=$KES_KEY
OPERATIONAL_CERTIFICATE_PATH=$NODE_CERT
NETWORK=$NODE_NETWORK
AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
RUN_INTERVAL=60000
DB_DIRECTORY=$NETWORK_DB_PATH
CARDANO_NODE_SOCKET_PATH=$NETWORK_SOCKET_PATH
CARDANO_CLI_PATH=$CNCLI
DATA_STORES_DIRECTORY=$MITHRIL_PATH/stores
STORE_RETENTION_LIMIT=5
ERA_READER_ADAPTER_TYPE=cardano-chain
ERA_READER_ADAPTER_PARAMS=$MITHRIL_AGGREGATOR_PARAMS
ENABLE_METRICS_SERVER=$MITHRIL_PROMETHEUS
METRICS_SERVER_IP=$MITHRIL_METRICS_SERVER_IP
METRICS_SERVER_PORT=$MITHRIL_METRICS_SERVER_PORT
" >"$MITHRIL_PATH/mithril-signer.env" || _mithril_fail 'Could not write mithril-signer.env' || return 1

    if [ $MITHRIL_RELAY_HOST ]; then
        echo "RELAY_ENDPOINT=$MITHRIL_RELAY_HOST:$MITHRIL_RELAY_PORT" >>"$MITHRIL_PATH/mithril-signer.env" || \
            _mithril_fail 'Could not append relay endpoint to mithril-signer.env' || return 1
    fi
    return 0
}

mithril_install_signer_service() {
    _require_producer_node || return 1
    local dir="$(dirname "$0")/../../services"
    print 'INSTALL' "Creating mithril signer service: $MITHRIL_SERVICE"
    cp -p "$dir/mithril.service" "$dir/$MITHRIL_SERVICE.temp" || _mithril_fail 'Could not copy service template' || return 1
    sed -i "$dir/$MITHRIL_SERVICE.temp" \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|MITHRIL_PATH|$MITHRIL_PATH|g" \
        -e "s|MITHRIL_SIGNER|$MITHRIL_SIGNER|g" \
        -e "s|MITHRIL_SERVICE|$MITHRIL_SERVICE|g" || _mithril_fail 'Could not configure service file' || return 1
    sudo cp -p "$dir/$MITHRIL_SERVICE.temp" "$SERVICE_PATH/$MITHRIL_SERVICE" || _mithril_fail 'Could not install service file' || return 1
    sudo systemctl daemon-reload || _mithril_fail 'Could not reload systemd' || return 1
    sudo systemctl enable "$MITHRIL_SERVICE" || _mithril_fail 'Could not enable mithril service' || return 1
    sudo systemctl start "$MITHRIL_SERVICE" || _mithril_fail 'Could not start mithril service' || return 1
    rm "$dir/$MITHRIL_SERVICE.temp" || _mithril_fail 'Could not remove temporary service file' || return 1
    print 'INSTALL' "Mithril service created: $MITHRIL_SERVICE" $green
    return 0
}

mithril_install_squid() {
    _require_relay_node || return 1
    mkdir -p downloads || _mithril_fail 'Could not create downloads directory' || return 1
    wget -O "downloads/squid-$MITHRIL_SQUID_VERSION.tar.gz" "$MITHRIL_SQUID_REMOTE" || _mithril_fail 'Could not download squid' || return 1
    tar -xvzf "downloads/squid-$MITHRIL_SQUID_VERSION.tar.gz" -C downloads || _mithril_fail 'Could not extract squid archive' || return 1
    cd "downloads/squid-$MITHRIL_SQUID_VERSION" || _mithril_fail 'Could not enter squid source directory' || return 1

    ./configure \
        --prefix=/opt/squid \
        --localstatedir=/opt/squid/var \
        --libexecdir=/opt/squid/lib/squid \
        --datadir=/opt/squid/share/squid \
        --sysconfdir=/etc/squid \
        --with-default-user=squid \
        --with-logdir=/opt/squid/var/log/squid \
        --with-pidfile=/opt/squid/var/run/squid.pid || _mithril_fail 'Could not configure squid' || return 1

    make || _mithril_fail 'Could not build squid' || return 1
    sudo make install || _mithril_fail 'Could not install squid' || return 1
    /opt/squid/sbin/squid -v || _mithril_fail 'Installed squid binary is not runnable' || return 1
    remove_path downloads
    return 0
}

mithril_configure_squid() {
    _require_relay_node || return 1
    local ipAddress=$1
    local dir="$(dirname "$0")/../../services"
    if [[ ! $ipAddress ]]; then
        _mithril_fail 'Please supply an IP address' || return 1
    fi

    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak || _mithril_fail 'Could not backup squid.conf' || return 1
    printf "
# Listening port
http_port $MITHRIL_RELAY_PORT

# ACL for internal IP of your block producer node
acl block_producer_internal_ip src $MITHRIL_RELAY_HOST

# ACL for aggregator endpoint
acl aggregator_domain dstdomain .mithril.network

# ACL for SSL port only
acl SSL_port port 443

# Allowed traffic
http_access allow block_producer_internal_ip aggregator_domain SSL_port

# Do not disclose block producer internal IP
forwarded_for delete

# Turn off via header
via off

# Deny request for original source of a request
follow_x_forwarded_for deny all

# Anonymize request headers
request_header_access Authorization allow all
request_header_access Proxy-Authorization allow all
request_header_access Cache-Control allow all
request_header_access Content-Length allow all
request_header_access Content-Type allow all
request_header_access Date allow all
request_header_access Host allow all
request_header_access If-Modified-Since allow all
request_header_access Pragma allow all
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Connection allow all
request_header_access All deny all

# Disable cache
cache deny all

# Deny everything else
http_access deny all
" | sudo tee /etc/squid/squid.conf >/dev/null || _mithril_fail 'Could not write squid.conf' || return 1

    sudo adduser --system --no-create-home --group squid || _mithril_fail 'Could not create squid user' || return 1
    sudo chown squid -R /opt/squid/var/ || _mithril_fail 'Could not set squid var ownership' || return 1
    sudo chgrp squid -R /opt/squid/var/ || _mithril_fail 'Could not set squid var group' || return 1

    sudo cp -p "$dir/squid.service" "/etc/systemd/system/$MITHRIL_SQUID_SERVICE" || _mithril_fail 'Could not install squid service file' || return 1
    sudo systemctl daemon-reload || _mithril_fail 'Could not reload systemd' || return 1
    sudo systemctl start squid || _mithril_fail 'Could not start squid service' || return 1
    sudo systemctl enable squid || _mithril_fail 'Could not enable squid service' || return 1

    print 'MITHRIL' 'Squid service started' $green
    return 0
}

mithril_start() {
    _require_producer_node || return 1
    sudo systemctl start "$MITHRIL_SERVICE" || _mithril_fail 'Could not start mithril service' || return 1
    print 'MITHRIL' "Mithril service started" $green
    return 0
}

mithril_stop() {
    _require_producer_node || return 1
    sudo systemctl stop "$MITHRIL_SERVICE" || _mithril_fail 'Could not stop mithril service' || return 1
    print 'MITHRIL' "Mithril service stopped" $green
    return 0
}

mithril_restart() {
    _require_producer_node || return 1
    sudo systemctl restart "$MITHRIL_SERVICE" || _mithril_fail 'Could not restart mithril service' || return 1
    print 'MITHRIL' "Mithril service restarted" $green
    return 0
}

mithril_watch() {
    _require_warm_node || return 1
    journalctl -u "$MITHRIL_SERVICE" -f -o cat
}

mithril_status() {
    _require_producer_node || return 1
    sudo systemctl status "$MITHRIL_SERVICE"
}

mithril_start_squid() {
    _require_relay_node || return 1
    sudo systemctl start "$MITHRIL_SQUID_SERVICE" || _mithril_fail 'Could not start squid service' || return 1
    print 'MITHRIL' "Squid service started" $green
    return 0
}

mithril_stop_squid() {
    _require_relay_node || return 1
    sudo systemctl stop "$MITHRIL_SQUID_SERVICE" || _mithril_fail 'Could not stop squid service' || return 1
    print 'MITHRIL' "Squid service stopped" $green
    return 0
}

mithril_restart_squid() {
    _require_relay_node || return 1
    sudo systemctl restart "$MITHRIL_SQUID_SERVICE" || _mithril_fail 'Could not restart squid service' || return 1
    print 'MITHRIL' "Squid service restarted" $green
    return 0
}

mithril_watch_squid() {
    _require_relay_node || return 1
    journalctl -u "$MITHRIL_SQUID_SERVICE" -f -o cat
}

mithril_status_squid() {
    _require_relay_node || return 1
    sudo systemctl status "$MITHRIL_SQUID_SERVICE"
}

mithril_verify_signer_registration() {
    _require_producer_node || return 1
    export PARTY_ID=$(<"$POOL_ID")
    export AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
    bash "$MITHRIL_PATH/verify_signer_registration.sh"
}

mithril_verify_signer_signature() {
    _require_producer_node || return 1
    export PARTY_ID=$(<"$POOL_ID")
    export AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
    bash "$MITHRIL_PATH/verify_signer_signature.sh"
}

case $1 in
    update) mithril_update ;;
    target) mithril_update_target_version ;;
    current) mithril_update_current_version ;;
    check) mithril_update_check_version ;;
    download) mithril_download ;;
    sync) mithril_sync ;;
    check_compatability) mithril_check_compatability ;;
    install_signer_env) mithril_install_signer_env ;;
    install_signer_service) mithril_install_signer_service ;;
    install_squid) mithril_install_squid ;;
    configure_squid) mithril_configure_squid "${@:2}" ;;
    start) mithril_start ;;
    stop) mithril_stop ;;
    restart) mithril_restart ;;
    watch) mithril_watch ;;
    status) mithril_status ;;
    start_squid) mithril_start_squid ;;
    stop_squid) mithril_stop_squid ;;
    restart_squid) mithril_restart_squid ;;
    watch_squid) mithril_watch_squid ;;
    status_squid) mithril_status_squid ;;
    verify_registration) mithril_verify_signer_registration ;;
    verify_signature) mithril_verify_signer_signature ;;
    help) help "${2:-"--help"}" ;;
    *) help "${2:-"--help"}" ;;
esac
exit $?
