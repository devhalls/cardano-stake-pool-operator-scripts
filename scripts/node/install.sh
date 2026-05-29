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
#   - configs) Sync node config files from the repo (overwrites bundled files; prompts for topology).
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

_confirm_yes() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
    esac
    return 1
}

_topology_parse_endpoint() {
    local spec="$1"
    local label="$2"
    spec="$(echo "$spec" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    if [[ "$spec" != *:* ]]; then
        _install_fail "$label must be host:port (got: $spec)" || return 1
    fi
    TOPOLOGY_PARSED_HOST="${spec%:*}"
    TOPOLOGY_PARSED_PORT="${spec##*:}"
    if ! [[ "$TOPOLOGY_PARSED_PORT" =~ ^[0-9]+$ ]]; then
        _install_fail "$label port must be numeric (got: $TOPOLOGY_PARSED_PORT)" || return 1
    fi
    return 0
}

_topology_access_points_json() {
    local endpoints_csv="$1"
    local label="$2"
    local json='[]'
    local spec
    while IFS= read -r spec; do
        [ -z "$spec" ] && continue
        _topology_parse_endpoint "$spec" "$label" || return 1
        json=$(echo "$json" | jq --arg host "$TOPOLOGY_PARSED_HOST" --argjson port "$TOPOLOGY_PARSED_PORT" \
            '. + [{address: $host, port: $port}]') || _install_fail "Could not build access point for $spec" || return 1
    done < <(echo "$endpoints_csv" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -v '^$')
    echo "$json"
}

_require_topology_env() {
    case $NODE_TYPE in
        producer)
            if [ -n "${NODE_TOPOLOGY_RELAY_HOSTS:-}" ]; then
                return 0
            fi
            [ -f "$CONFIG_SOURCE/topology.json" ] || \
                _install_fail 'NODE_TOPOLOGY_RELAY_HOSTS is empty and no bundled topology.json to use' || return 1
            return 0
            ;;
        relay)
            if [ -n "${NODE_TOPOLOGY_BP_HOST:-}" ]; then
                return 0
            fi
            [ -f "$CONFIG_SOURCE/topology.json" ] || \
                _install_fail 'NODE_TOPOLOGY_BP_HOST is empty and no bundled topology.json to use' || return 1
            return 0
            ;;
        *)
            _install_fail "Unknown NODE_TYPE for topology: $NODE_TYPE" || return 1
            ;;
    esac
}

_render_topology_relay() {
    local template="$1"
    local dest="$2"
    _require_topology_env || return 1
    _topology_parse_endpoint "$NODE_TOPOLOGY_BP_HOST" 'NODE_TOPOLOGY_BP_HOST' || return 1
    if grep -q '__NODE_TOPOLOGY_BP_HOST__' "$template" 2>/dev/null; then
        sed \
            -e "s|__NODE_TOPOLOGY_BP_HOST__|${TOPOLOGY_PARSED_HOST}|g" \
            -e "s|__NODE_TOPOLOGY_BP_PORT__|${TOPOLOGY_PARSED_PORT}|g" \
            "$template" >"$dest" || _install_fail 'Could not render relay topology template' || return 1
    else
        jq \
            --arg host "$TOPOLOGY_PARSED_HOST" \
            --argjson port "$TOPOLOGY_PARSED_PORT" \
            '.localRoots[0].accessPoints = [{address: $host, port: $port}]
            | .localRoots[0].trustable = true' \
            "$template" >"$dest" || _install_fail 'Could not render relay topology from bundled template' || return 1
    fi
    return 0
}

_write_topology_producer() {
    local dest="$1"
    local template="$CONFIG_SOURCE/topology-producer.json"
    [ -f "$template" ] || template="$CONFIG_SOURCE/topology.json"
    local access_points relay_count use_ledger
    _require_topology_env || return 1
    access_points=$(_topology_access_points_json "$NODE_TOPOLOGY_RELAY_HOSTS" 'NODE_TOPOLOGY_RELAY_HOSTS') || \
        _install_fail 'Could not build relay access points for producer topology' || return 1
    relay_count=$(echo "$access_points" | jq 'length') || return 1
    if [ "$relay_count" -lt 1 ]; then
        _install_fail 'NODE_TOPOLOGY_RELAY_HOSTS must contain at least one relay address' || return 1
    fi
    use_ledger=$(jq -r '.useLedgerAfterSlot // 185500763' "$template" 2>/dev/null)
    jq -n \
        --argjson accessPoints "$access_points" \
        --argjson valency "$relay_count" \
        --argjson useLedgerAfterSlot "$use_ledger" \
        '{
            localRoots: [{
                accessPoints: $accessPoints,
                advertise: false,
                trustable: true,
                valency: $valency
            }],
            peerSnapshotFile: "peer-snapshot.json",
            publicRoots: [{accessPoints: [], advertise: false}],
            useLedgerAfterSlot: $useLedgerAfterSlot
        }' >"$dest" || _install_fail 'Could not write producer topology' || return 1
    return 0
}

_render_topology_template() {
    local template="$1"
    local dest="$2"
    cp -p "$template" "$dest" || _install_fail "Could not copy topology template $template" || return 1
    return 0
}

_install_topology_from_repo() {
    _require_topology_env || return 1
    case $NODE_TYPE in
        producer)
            if [ -z "${NODE_TOPOLOGY_RELAY_HOSTS:-}" ]; then
                _render_topology_template "$CONFIG_SOURCE/topology.json" "$NETWORK_PATH/topology.json" || return 1
                print 'INSTALL' 'Installed producer topology from topology.json (no relays configured)' $green
                return 0
            fi
            _write_topology_producer "$NETWORK_PATH/topology.json" || return 1
            print 'INSTALL' 'Installed producer topology from NODE_TOPOLOGY_RELAY_HOSTS' $green
            return 0
            ;;
        relay)
            if [ -z "${NODE_TOPOLOGY_BP_HOST:-}" ]; then
                _render_topology_template "$CONFIG_SOURCE/topology.json" "$NETWORK_PATH/topology.json" || return 1
                print 'INSTALL' 'Installed relay topology from topology.json (no BP configured)' $green
                return 0
            fi
            local template_path="$CONFIG_SOURCE/topology-relay.json"
            [ -f "$template_path" ] || template_path="$CONFIG_SOURCE/topology.json"
            _render_topology_relay "$template_path" "$NETWORK_PATH/topology.json" || return 1
            print 'INSTALL' 'Installed relay topology from NODE_TOPOLOGY_BP_HOST' $green
            return 0
            ;;
        *)
            _install_fail "Unknown NODE_TYPE for topology: $NODE_TYPE" || return 1
            ;;
    esac
}

_topology_env_configured() {
    case $NODE_TYPE in
        producer) [ -n "${NODE_TOPOLOGY_RELAY_HOSTS:-}" ] ;;
        relay) [ -n "${NODE_TOPOLOGY_BP_HOST:-}" ] ;;
        *) return 1 ;;
    esac
}

_sync_topology() {
    if _topology_env_configured; then
        _install_topology_from_repo || return 1
        return 0
    fi
    if [ -f "$NETWORK_PATH/topology.json" ]; then
        if [ -t 0 ]; then
            print 'INSTALL' "Existing topology: $NETWORK_PATH/topology.json" $orange
            if ! _confirm_yes 'Replace topology.json from the repo template?'; then
                print 'INSTALL' 'Keeping existing topology.json' $orange
                return 0
            fi
        else
            print 'INSTALL' 'Non-interactive: keeping existing topology.json' $orange
            return 0
        fi
    fi
    _install_topology_from_repo || return 1
    return 0
}

_apply_node_metrics_config() {
    local config_file="$1"
    [ -f "$config_file" ] || return 0
    grep -q 'PrometheusSimple suffix' "$config_file" || return 0
    sed -i "$config_file" \
        -e "s|PrometheusSimple suffix [^ ]* [0-9]*|PrometheusSimple suffix ${NODE_METRICS_HOST} ${NODE_METRICS_PORT}|" \
        || _install_fail "Could not apply node metrics settings to $config_file" || return 1
    return 0
}

_render_prometheus_yml() {
    local src="$1"
    local dest="$2"
    sed \
        -e "s|__NODE_METRICS_PORT__|${NODE_METRICS_PORT}|g" \
        -e "s|__MITHRIL_METRICS_SERVER_PORT__|${MITHRIL_METRICS_SERVER_PORT}|g" \
        "$src" >"$dest" || _install_fail 'Could not render prometheus.yml' || return 1
    return 0
}

_sync_node_configs() {
    _require_warm_node || return 1
    if [ ! -d "$CONFIG_SOURCE" ]; then
        _install_fail "No config files found for $NODE_VERSION/$NODE_NETWORK at $CONFIG_SOURCE" || return 1
    fi
    print 'INSTALL' "Syncing config files for $NODE_NETWORK ($NODE_VERSION)"
    for C in ${CONFIG_DOWNLOADS[@]}; do
        [ "$C" == 'topology.json' ] && continue
        if [ ! -f "$CONFIG_SOURCE/$C" ]; then
            _install_fail "Missing config file: $CONFIG_SOURCE/$C" || return 1
        fi
        cp -p "$CONFIG_SOURCE/$C" "$NETWORK_PATH/$C" || _install_fail "Failed to copy config: $C" || return 1
    done
    if [[ " ${CONFIG_DOWNLOADS[*]} " != *" config-bp.json "* ]] && [ ! -f "$NETWORK_PATH/config-bp.json" ]; then
        cp -p "$NETWORK_PATH/config.json" "$NETWORK_PATH/config-bp.json" || _install_fail 'Failed to create config-bp.json' || return 1
    fi
    _apply_node_metrics_config "$NETWORK_PATH/config.json" || return 1
    _apply_node_metrics_config "$NETWORK_PATH/config-bp.json" || return 1
    print 'INSTALL' "Review $CONFIG_PATH for local customisations (metrics port, tracing, etc.) before restart." $orange
    if [ "$NODE_TYPE" == 'producer' ]; then
        print 'INSTALL' "Producer also uses $NETWORK_PATH/config-bp.json — check both config files." $orange
    fi
    _sync_topology || return 1
    print 'INSTALL' "Synced configs for $NODE_NETWORK" $green
    return 0
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
    _sync_node_configs || return 1
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
        sudo ufw allow proto tcp from $monitoringIp to any port $NODE_METRICS_PORT || _install_fail "Could not configure ufw for port $NODE_METRICS_PORT" || return 1
        sudo ufw reload || _install_fail 'Could not reload ufw' || return 1
    fi
    sudo $PACKAGER install -y prometheus-node-exporter || _install_fail 'Could not install prometheus-node-exporter' || return 1

    sudo sed -i "/^ExecStart=/c\\ExecStart=$promPath --collector.textfile.directory=$NETWORK_PATH/stats --collector.textfile" "$servicePath" || \
        _install_fail 'Could not configure prometheus-node-exporter service' || return 1
    _apply_node_metrics_config "$CONFIG_PATH" || return 1

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
    _render_prometheus_yml "$serviceDir/prometheus.yml" "$serviceDir/prometheus.yml.temp" || return 1
    sudo cp -p "$serviceDir/prometheus.yml.temp" /etc/prometheus/prometheus.yml || _install_fail 'Could not copy prometheus.yml' || return 1
    rm -f "$serviceDir/prometheus.yml.temp" || _install_fail 'Could not remove temporary prometheus.yml' || return 1

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
    print 'INSTALL' "Set NODE_TOPOLOGY_* host:port values in env, then: scripts/node.sh install configs" $green
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
