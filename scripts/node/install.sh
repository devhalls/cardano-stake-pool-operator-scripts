#!/bin/bash
# Usage: node/install.sh (
#   install |
#   validate |
#   dependencies |
#   binaries |
#   build [...params] |
#   download [...params] |
#   configs |
#   guild |
#   prometheus_exporter [monitoringIp <STRING>] |
#   grafana |
#   service |
#   clean |
#   help [-h]
# )
#
# Info:
#
#   - install) Installs a Cardano node and all dependencies. Default value if no options are passed.
#   - validate) Validate if an installation can run.
#   - dependencies) Install package dependencies and node directories.
#   - binaries) Build or download the node binaries based on $NODE_BUILD.
#   - build) Build the node binaries from source.
#   - download) Download the node binaries.
#   - configs) Install node config files from the repo.
#   - guild) Download the guild gLiveView script.
#   - prometheus_exporter) Install Prometheus node exporter on the block producers and all relays. The monitoringIp is only used for producer nodes.
#   - grafana) Install Grafana on Monitoring Node only - must be a relay.
#   - service) Create the node systemctl service.
#   - clean) Clean the installation and remove all files.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../common.sh"

# Private functions

_install_die() {
    print 'ERROR' "$1" $red
    return 1
}

_install_fail() {
    _install_die "$1" || return 1
}

_install_failed() {
    local message="${1:-Node installation failed}"
    print 'ERROR' "$message" $red
    rm -rf "$NETWORK_PATH" "$BIN_PATH"
    exit 1
}

_require_warm_node() {
    if is_cold_device; then
        _install_fail 'This command can not be run on a cold device'
    fi
}

_require_relay_node() {
    if is_not_relay_device; then
        _install_fail 'This command can only be run on a relay device'
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _install_fail 'Installation cancelled' ;;
    esac
}

# Public functions

install_validate() {
    print 'INSTALL' 'Validating installation'
    if [ ! -f "$(dirname "$0")/../../env" ]; then
        _install_fail 'No env file found, please review the README.md' || return 1
    fi
    if [ -d "$NETWORK_PATH/keys" ]; then
        _install_fail 'Already installed, remove your current installation to reinstall' || return 1
    fi
    print 'INSTALL' 'Install validation passed' $green
    return 0
}

install_dependencies() {
    print 'INSTALL' 'Creating directories'
    mkdir -p "$NETWORK_PATH" \
        "$NETWORK_PATH/temp" \
        "$NETWORK_PATH/keys" \
        "$NETWORK_PATH/scripts" \
        "$NETWORK_PATH/logs" \
        "$NETWORK_PATH/stats" \
        "$BIN_PATH" || _install_fail 'Could not create node directories' || return 1
    print 'INSTALL' 'Dependencies installed' $green
    return 0
}

install_binaries() {
    _require_warm_node || return 1
    if [[ $NODE_BUILD == 1 ]]; then
        bash "$(dirname "$0")/download.sh" download || _install_failed 'Binary download failed'
    elif [[ $NODE_BUILD == 2 ]]; then
        bash "$(dirname "$0")/build.sh" build || _install_failed 'Binary build failed'
    else
        print 'INSTALL' 'Node binaries skipped' $green
    fi
    return 0
}

install_configs() {
    _require_warm_node || return 1
    if [ ! -d "$CONFIG_SOURCE" ]; then
        _install_fail "No config files found for $NODE_VERSION/$NODE_NETWORK at $CONFIG_SOURCE" || return 1
    fi
    print 'INSTALL' "Installing config files for $NODE_NETWORK ($NODE_VERSION)"
    for C in ${CONFIG_DOWNLOADS[@]}; do
        if [ ! -f "$CONFIG_SOURCE/$C" ]; then
            _install_fail "Missing config file: $CONFIG_SOURCE/$C" || return 1
        fi
        cp -p "$CONFIG_SOURCE/$C" "$NETWORK_PATH/$C" || _install_fail "Failed to copy config: $C" || return 1
    done
    if [ ! -f "$NETWORK_PATH/config-bp.json" ]; then
        cp -p "$NETWORK_PATH/config.json" "$NETWORK_PATH/config-bp.json" || _install_fail 'Failed to create config-bp.json' || return 1
    fi
    print 'INSTALL' "Installed configs for $NODE_NETWORK" $green
    return 0
}

install_guild() {
    _require_warm_node || return 1
    print 'INSTALL' "Downloading guild scripts"
    for G in ${GUILD_SCRIPT_DOWNLOADS[@]}; do
        wget -O "$NETWORK_PATH/scripts/$G" "$GUILD_REMOTE/$G"
        if [ $? -ne 0 ] || [ ! -s "$NETWORK_PATH/scripts/$G" ]; then
            _install_fail "Could not download guild script: $G" || return 1
        fi
    done
    chmod +x "$NETWORK_PATH/scripts/gLiveView.sh" || _install_fail 'Could not set guild script permissions' || return 1
    sed -i "$NETWORK_PATH/scripts/env" \
        -e "s|\#CONFIG=\"\${CNODE_HOME}\/files\/config.json\"|CONFIG=\"${NETWORK_PATH}\/config.json\"|g" \
        -e "s|\#SOCKET=\"\${CNODE_HOME}\/sockets\/node.socket\"|SOCKET=\"${NETWORK_SOCKET_PATH}\"|g" \
        -e "s|\#CNODE_PORT=6000|CNODE_PORT=\"${NODE_PORT}\"|g" \
        -e "s|\#CNODEBIN=\"\${HOME}\/.local\/bin\/cardano-node\"|CNODEBIN=\"${BIN_PATH}\/${NODE_NAME}\"|g" \
        -e "s|\#CCLI=\"\${HOME}\/.local\/bin\/cardano-cli\"|CCLI=\"${BIN_PATH}\/${NODE_CLI_NAME}\"|g" || \
        _install_fail 'Could not configure guild env script' || return 1
    print 'INSTALL' "Downloaded guild scripts" $green
    return 0
}

install_prometheus_exporter() {
    _require_warm_node || return 1
    print 'INSTALL' 'Prometheus exporter'
    local promPath=/usr/bin/prometheus-node-exporter
    local servicePath=/lib/systemd/system/prometheus-node-exporter.service
    local monitoringIp=${1}

    if [ $NODE_TYPE == 'producer' ] && [ $NODE_NETWORK == 'mainnet' ]; then
        if [ ! $monitoringIp ]; then
            _install_fail 'Please supply your monitoring node IP address' || return 1
        fi
        sudo ufw allow proto tcp from $monitoringIp to any port 9100 || _install_fail 'Could not configure ufw for port 9100' || return 1
        sudo ufw allow proto tcp from $monitoringIp to any port 12798 || _install_fail 'Could not configure ufw for port 12798' || return 1
        sudo ufw reload || _install_fail 'Could not reload ufw' || return 1
    fi
    sudo $PACKAGER install -y prometheus-node-exporter || _install_fail 'Could not install prometheus-node-exporter' || return 1

    sudo sed -i "/^ExecStart=/c\\ExecStart=$promPath --collector.textfile.directory=$NETWORK_PATH/stats --collector.textfile" "$servicePath" || \
        _install_fail 'Could not configure prometheus-node-exporter service' || return 1
    sed -i "$CONFIG_PATH" -e "s/127.0.0.1/0.0.0.0/g" || _install_fail 'Could not update node config for prometheus' || return 1

    sudo systemctl enable prometheus-node-exporter.service || _install_fail 'Could not enable prometheus-node-exporter service' || return 1
    sudo systemctl restart prometheus-node-exporter.service || _install_fail 'Could not restart prometheus-node-exporter service' || return 1
    print 'INSTALL' 'Prometheus exporter installed' $green
    return 0
}

install_grafana() {
    _require_relay_node || return 1
    print 'INSTALL' 'Grafana dashboard'

    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add - || _install_fail 'Could not add Grafana GPG key' || return 1
    echo "deb https://packages.grafana.com/oss/deb stable main" >grafana.list
    sudo mv grafana.list /etc/apt/sources.list.d/grafana.list || _install_fail 'Could not configure Grafana apt source' || return 1
    sudo $PACKAGER update && sudo $PACKAGER install -y prometheus grafana || _install_fail 'Could not install Grafana and Prometheus packages' || return 1

    source ~/.bashrc
    sudo grafana-cli plugins install grafana-clock-panel || _install_fail 'Could not install grafana-clock-panel plugin' || return 1
    sudo grafana-cli plugins install marcusolsson-csv-datasource || _install_fail 'Could not install csv-datasource plugin' || return 1

    serviceDir="$SERVICES_SOURCE"
    sudo cp -p "$serviceDir/prometheus.yml" /etc/prometheus/prometheus.yml || _install_fail 'Could not copy prometheus.yml' || return 1

    sudo sed -i "/# disable user signup \/ registration/{n;s/.*/allow_sign_up = false/}" "/etc/grafana/grafana.ini" || \
        _install_fail 'Could not configure grafana.ini' || return 1
    if ! sudo grep -q "plugin.marcusolsson-csv-datasource" /etc/grafana/grafana.ini; then
        echo "[plugin.marcusolsson-csv-datasource]" | sudo tee -a /etc/grafana/grafana.ini >/dev/null || _install_fail 'Could not update grafana.ini' || return 1
        echo "allow_local_mode = true" | sudo tee -a /etc/grafana/grafana.ini >/dev/null || _install_fail 'Could not update grafana.ini' || return 1
    fi

    sudo systemctl enable grafana-server.service || _install_fail 'Could not enable grafana-server service' || return 1
    sudo systemctl enable prometheus.service || _install_fail 'Could not enable prometheus service' || return 1
    sudo systemctl enable prometheus-node-exporter.service || _install_fail 'Could not enable prometheus-node-exporter service' || return 1
    sudo systemctl restart grafana-server.service || _install_fail 'Could not restart grafana-server service' || return 1
    sudo systemctl restart prometheus.service || _install_fail 'Could not restart prometheus service' || return 1
    sudo systemctl restart prometheus-node-exporter.service || _install_fail 'Could not restart prometheus-node-exporter service' || return 1
    print 'INSTALL' 'Grafana dashboard installed' $green
    return 0
}

install_service() {
    if platform_ctl; then
        local dir="$SERVICES_SOURCE"
        print 'INSTALL' "Creating node service: $NETWORK_SERVICE"
        cp -p "$dir/cardano-node.service" "$dir/$NETWORK_SERVICE.temp" || _install_fail 'Could not copy service template' || return 1
        sed -i "$dir/$NETWORK_SERVICE.temp" \
            -e "s|NODE_NETWORK|$NODE_NETWORK|g" \
            -e "s|NODE_HOME|$NODE_HOME|g" \
            -e "s|NODE_USER|$NODE_USER|g" \
            -e "s|NETWORK_SERVICE|$NETWORK_SERVICE|g" || _install_fail 'Could not configure service file' || return 1
        sudo cp -p "$dir/$NETWORK_SERVICE.temp" "$SERVICE_PATH/$NETWORK_SERVICE" || _install_fail 'Could not install service file' || return 1
        sudo systemctl daemon-reload || _install_fail 'Could not reload systemd' || return 1
        sudo systemctl enable "$NETWORK_SERVICE" || _install_fail 'Could not enable node service' || return 1
        rm "$dir/$NETWORK_SERVICE.temp" || _install_fail 'Could not remove temporary service file' || return 1
        print 'INSTALL' "Node service created: $NETWORK_SERVICE" $green
    else
        print 'INSTALL' "Systemctl not supported, skipping and assuming docker install" $orange
    fi
    return 0
}

install_clean() {
    _confirm 'Are you sure?' || return 1
    rm -rf "$NETWORK_PATH" "$BIN_PATH" || _install_fail 'Could not delete node directories' || return 1
    sudo rm -f "$SERVICE_PATH/$NETWORK_SERVICE" || _install_fail 'Could not delete node service file' || return 1
    print 'INSTALL' "Node files have been deleted" $green
    return 0
}

install() {
    install_validate || return 1
    install_dependencies || return 1
    install_binaries || return 1
    install_configs || return 1
    install_guild || return 1
    install_service || return 1
    $CNNODE --version || _install_fail 'Installed cardano-node binary is not runnable' || return 1
    $CNCLI --version || _install_fail 'Installed cardano-cli binary is not runnable' || return 1
    print 'INSTALL' "Edit your topology config at $NETWORK_PATH/topology.json" $green
    return 0
}

case $1 in
    install) install ;;
    validate) install_validate ;;
    dependencies) install_dependencies ;;
    binaries) install_binaries ;;
    build) bash "$(dirname "$0")/build.sh" "${@:2}" ;;
    download) bash "$(dirname "$0")/download.sh" "${@:2}" ;;
    configs) install_configs ;;
    guild) install_guild ;;
    prometheus_exporter) install_prometheus_exporter "${@:2}" ;;
    grafana) install_grafana ;;
    service) install_service ;;
    clean) install_clean ;;
    help) help "${2:-"--help"}" ;;
    *) install ;;
esac
exit $?
