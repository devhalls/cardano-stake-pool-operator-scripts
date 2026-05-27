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

extract_mithril_release() {
    local filename="$1"
    local extract_dir="downloads/extract"

    remove_path "$extract_dir"
    mkdir -p "$extract_dir"
    tar -xvzf "downloads/$filename" -C "$extract_dir"
    cp -a "$extract_dir/." "$BIN_PATH/"
}

mithril_download() {
    exit_if_cold
    print 'MITHRIL' "Downloading mithril binaries"
    local filenames=($(mithril_release_filenames))
    local filename

    if download_release_file "$MITHRIL_REMOTE" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        extract_mithril_release "$filename"
        chmod +x -R $BIN_PATH
        remove_path downloads
        mkdir -p $MITHRIL_PATH
        echo "$MITHRIL_VERSION" > "$MITHRIL_PATH/version"
        $MITHRIL_CLIENT --version
        $MITHRIL_SIGNER --version
        print 'DOWNLOAD' "Mithril binaries moved to $BIN_PATH" $green
        return 0
    fi

    remove_path downloads
    print 'ERROR' "Unable to download mithril binaries for $(platform)/$(platform_arch)" $red
    exit 1
}

mithril_sync() {
    exit_if_cold
    print 'MITHRIL' "Syncing db via mithril"
    export AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
    if [[ $NODE_NETWORK == 'preprod' ]]; then
        export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/genesis.vkey)
    elif [[ $NODE_NETWORK == 'preview' ]]; then
        export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/genesis.vkey)
    elif [[ $NODE_NETWORK == 'mainnet' ]]; then
        export GENESIS_VERIFICATION_KEY=$(curl -s https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/genesis.vkey)
    else
        print "ERROR" "$NODE_NETWORK is not supported by mithril sync"
        exit 1
    fi
    export NETWORK=$NODE_NETWORK

    $MITHRIL_CLIENT cardano-db download --download-dir $NETWORK_PATH latest

    if [ $? -ne 0 ]; then
        print 'MITHRIL' "Unable to sync with mithril" $red
        exit 1
    fi
    print 'MITHRIL' "DB synced via mithril, please restart your node" $green
    return 0
}

mithril_check_compatability() {
    exit_if_not_producer
    print 'MITHRIL' 'Min node version:'
    wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/networks.json |
        jq -r ".\"$NODE_NETWORK\".\"cardano-minimum-version\".\"mithril-signer\""
}

mithril_update_target_version() {
    echo $MITHRIL_VERSION
}

mithril_update_current_version() {
    if [ -f "$MITHRIL_PATH/version" ]; then
        cat "$MITHRIL_PATH/version"
    else
        echo ""
    fi
}

mithril_update_check_version() {
    local latest current
    latest=$(mithril_update_target_version)
    current=$(mithril_update_current_version)
    if [ "$current" == "$latest" ]; then
        print 'UPDATE' "Mithril is already up to date (v$current)" $green
        exit 1
    elif [ -z "$current" ] || [ -z "$latest" ]; then
        print 'UPDATE' "Unable to read update versions [current:$current] [latest:$latest]" $red
        exit 1
    else
        echo $latest
    fi
}

mithril_update() {
    exit_if_not_producer
    local latest
    latest=$(mithril_update_check_version)
    confirm "Please confirm mithril update to version: $latest?"
    mithril_stop
    mithril_download
    mithril_restart
    $MITHRIL_CLIENT --version
    $MITHRIL_SIGNER --version
    print 'UPDATE' "Mithril updated and restarted" $green
}

mithril_install_signer_env() {
    exit_if_not_producer
    mkdir -p $MITHRIL_PATH
    rm $MITHRIL_PATH/mithril-signer.env

    wget -O $MITHRIL_PATH/verify_signer_registration.sh https://mithril.network/doc/scripts/verify_signer_registration.sh
    chmod +x $MITHRIL_PATH/verify_signer_registration.sh
    wget -O $MITHRIL_PATH/verify_signer_signature.sh https://mithril.network/doc/scripts/verify_signer_signature.sh
    chmod +x $MITHRIL_PATH/verify_signer_signature.sh

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
" >$MITHRIL_PATH/mithril-signer.env

    if [ $MITHRIL_RELAY_HOST ]; then
        echo "RELAY_ENDPOINT=$MITHRIL_RELAY_HOST:$MITHRIL_RELAY_PORT" >>$MITHRIL_PATH/mithril-signer.env
    fi
}

mithril_install_signer_service() {
    exit_if_not_producer
    print 'INSTALL' "Creating mithril signer service: $MITHRIL_SERVICE"
    cp -p services/$MITHRIL_SERVICE services/$MITHRIL_SERVICE.temp
    sed -i services/$MITHRIL_SERVICE.temp \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|MITHRIL_PATH|$MITHRIL_PATH|g" \
        -e "s|MITHRIL_SIGNER|$MITHRIL_SIGNER|g" \
        -e "s|MITHRIL_SERVICE|$MITHRIL_SERVICE|g"
    sudo cp -p services/$MITHRIL_SERVICE.temp $SERVICE_PATH/$MITHRIL_SERVICE
    sudo systemctl daemon-reload
    sudo systemctl enable $MITHRIL_SERVICE
    sudo systemctl start $MITHRIL_SERVICE
    rm services/$MITHRIL_SERVICE.temp
    print 'INSTALL' "Mithril service created: $MITHRIL_SERVICE" $green
    return 0
}

mithril_install_squid() {
    exit_if_not_relay
    mkdir -p downloads
    wget -O "downloads/squid-$MITHRIL_SQUID_VERSION.tar.gz" "$MITHRIL_SQUID_REMOTE"
    if [ $? -eq 0 ]; then
        tar -xvzf downloads/squid-$MITHRIL_SQUID_VERSION.tar.gz -C downloads
        cd downloads/squid-$MITHRIL_SQUID_VERSION

        ./configure \
            --prefix=/opt/squid \
            --localstatedir=/opt/squid/var \
            --libexecdir=/opt/squid/lib/squid \
            --datadir=/opt/squid/share/squid \
            --sysconfdir=/etc/squid \
            --with-default-user=squid \
            --with-logdir=/opt/squid/var/log/squid \
            --with-pidfile=/opt/squid/var/run/squid.pid

        make
        sudo make install
        /opt/squid/sbin/squid -v
        remove_path downloads
    else
        print 'ERROR' 'Could not install squid' $red
    fi
}

mithril_configure_squid() {
    exit_if_not_relay
    ipAddress=$1
    if [[ ! $ipAddress ]]; then
        print 'ERROR' 'Please supply and IP address'
        exit 1
    fi

    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
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
" | sudo tee /etc/squid/squid.conf >/dev/null

    sudo adduser --system --no-create-home --group squid
    sudo chown squid -R /opt/squid/var/
    sudo chgrp squid -R /opt/squid/var/

    sudo cp -p services/$MITHRIL_SQUID_SERVICE /etc/systemd/system/$MITHRIL_SQUID_SERVICE
    sudo systemctl daemon-reload
    sudo systemctl start squid
    sudo systemctl enable squid

    print 'MITHRIL' 'Squid service started' $green
}

mithril_start() {
    exit_if_not_producer
    sudo systemctl start $MITHRIL_SERVICE
    print 'MITHRIL' "Mithril service started" $green
}

mithril_stop() {
    exit_if_not_producer
    sudo systemctl stop $MITHRIL_SERVICE
    print 'MITHRIL' "Mithril service stopped" $green
}

mithril_restart() {
    exit_if_not_producer
    sudo systemctl restart $MITHRIL_SERVICE
    print 'MITHRIL' "Mithril service restarted" $green
}

mithril_watch() {
    exit_if_cold
    journalctl -u $MITHRIL_SERVICE -f -o cat
}

mithril_status() {
    exit_if_not_producer
    sudo systemctl status $MITHRIL_SERVICE
}

mithril_start_squid() {
    exit_if_not_relay
    sudo systemctl start $MITHRIL_SQUID_SERVICE
    print 'MITHRIL' "Squid service started" $green
}

mithril_stop_squid() {
    exit_if_not_relay
    sudo systemctl stop $MITHRIL_SQUID_SERVICE
    print 'MITHRIL' "Squid service stopped" $green
}

mithril_restart_squid() {
    exit_if_not_relay
    sudo systemctl restart $MITHRIL_SQUID_SERVICE
    print 'MITHRIL' "Squid service restarted" $green
}

mithril_watch_squid() {
    exit_if_not_relay
    journalctl -u $MITHRIL_SQUID_SERVICE -f -o cat
}

mithril_status_squid() {
    exit_if_not_relay
    sudo systemctl status $MITHRIL_SQUID_SERVICE
}

mithril_verify_signer_registration() {
    exit_if_not_producer
    export PARTY_ID=$(<$POOL_ID)
    export AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
    bash $MITHRIL_PATH/verify_signer_registration.sh
}

mithril_verify_signer_signature() {
    exit_if_not_producer
    export PARTY_ID=$(<$POOL_ID)
    export AGGREGATOR_ENDPOINT=$MITHRIL_AGGREGATOR_ENDPOINT
    bash $MITHRIL_PATH/verify_signer_signature.sh
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
