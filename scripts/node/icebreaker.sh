#!/bin/bash
# Usage: node/icebreaker.sh (
#   download |
#   install |
#   run |
#   start |
#   stop |
#   restart |
#   watch |
#   status |
#   help [-h]
# )
#
# Info:
#
#   - download) Download the icebreaker binaries and run the init installation. Note this setup currently allows for a single binary used by all networks.
#   - install) Install the icebreaker service.
#   - run) Run the icebreaker service.
#   - start) Starts the icebreaker service.
#   - stop) Stops the icebreaker service.
#   - restart) Restarts the icebreaker service.
#   - watch) Watch icebreaker service logs.
#   - status) Display icebreaker service status.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../common.sh"

# Private functions

_icebreaker_die() {
    print 'ERROR' "$1" $red
    return 1
}

_icebreaker_fail() {
    _icebreaker_die "$1" || return 1
}

_require_relay_node() {
    if is_not_relay_device; then
        _icebreaker_fail 'This command can only be run on a relay device'
    fi
}

_require_warm_node() {
    if is_cold_device; then
        _icebreaker_fail 'This command can not be run on a cold device'
    fi
}

# Public functions

icebreaker_download() {
    _require_relay_node || return 1
    print 'ICEBREAKER' "Downloading icebreaker binaries"
    curl -fsSL \
         https://github.com/blockfrost/blockfrost-platform/releases/latest/download/curl-bash-install.sh \
         | bash || _icebreaker_fail 'Could not download icebreaker binaries' || return 1

    source "$HOME/.local/opt/blockfrost-platform/add-to-path.sh" || _icebreaker_fail 'Could not source icebreaker path script' || return 1
    blockfrost-platform --init || _icebreaker_fail 'Could not initialize blockfrost platform' || return 1
    return 0
}

icebreaker_install() {
    _require_relay_node || return 1
    local dir="$SERVICES_SOURCE"
    print 'ICEBREAKER' "Creating icebreaker service: $ICEBREAKER_SERVICE"
    cp -p "$dir/$ICEBREAKER_NAME.service" "$dir/$ICEBREAKER_SERVICE.temp" || _icebreaker_fail 'Could not copy service template' || return 1
    sed -i "$dir/$ICEBREAKER_SERVICE.temp" \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|NODE_HOME|$NODE_HOME|g" \
        -e "s|ICEBREAKER_NAME|$ICEBREAKER_NAME|g" \
        -e "s|ICEBREAKER_SERVICE|$ICEBREAKER_SERVICE|g" || _icebreaker_fail 'Could not configure service file' || return 1
    sudo cp -p "$dir/$ICEBREAKER_SERVICE.temp" "$SERVICE_PATH/$ICEBREAKER_SERVICE" || _icebreaker_fail 'Could not install service file' || return 1
    sudo systemctl daemon-reload || _icebreaker_fail 'Could not reload systemd' || return 1
    sudo systemctl enable "$ICEBREAKER_SERVICE" || _icebreaker_fail 'Could not enable icebreaker service' || return 1
    sudo systemctl start "$ICEBREAKER_SERVICE" || _icebreaker_fail 'Could not start icebreaker service' || return 1
    rm "$dir/$ICEBREAKER_SERVICE.temp" || _icebreaker_fail 'Could not remove temporary service file' || return 1
    print 'ICEBREAKER' "Icebreaker service created: $ICEBREAKER_SERVICE" $green
    return 0
}

icebreaker_run() {
    $BLOCKFROST --network $NODE_NETWORK \
       --node-socket-path $NETWORK_SOCKET_PATH \
       --secret $ICEBREAKER_SECRET \
       --reward-address $ICEBREAKER_REWARD_ADDR
}

icebreaker_start() {
    _require_relay_node || return 1
    sudo systemctl start "$ICEBREAKER_SERVICE" || _icebreaker_fail 'Could not start icebreaker service' || return 1
    print 'ICEBREAKER' "Icebreaker service started" $green
    return 0
}

icebreaker_stop() {
    _require_relay_node || return 1
    sudo systemctl stop "$ICEBREAKER_SERVICE" || _icebreaker_fail 'Could not stop icebreaker service' || return 1
    print 'ICEBREAKER' "Icebreaker service stopped" $green
    return 0
}

icebreaker_restart() {
    _require_relay_node || return 1
    sudo systemctl restart "$ICEBREAKER_SERVICE" || _icebreaker_fail 'Could not restart icebreaker service' || return 1
    print 'ICEBREAKER' "Icebreaker service restarted" $green
    return 0
}

icebreaker_watch() {
    _require_warm_node || return 1
    journalctl -u "$ICEBREAKER_SERVICE" -f -o cat
}

icebreaker_status() {
    _require_relay_node || return 1
    sudo systemctl status "$ICEBREAKER_SERVICE"
}

case $1 in
    download) icebreaker_download ;;
    install) icebreaker_install ;;
    run) icebreaker_run ;;
    start) icebreaker_start ;;
    stop) icebreaker_stop ;;
    restart) icebreaker_restart ;;
    watch) icebreaker_watch ;;
    status) icebreaker_status ;;
    help) help "${2:-"--help"}" ;;
    *) help "${2:-"--help"}" ;;
esac
exit $?
