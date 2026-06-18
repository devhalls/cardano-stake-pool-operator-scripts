#!/bin/bash
# Usage: ogmios.sh (
#   update |
#   target |
#   current |
#   check |
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
#   - update) Updates ogmios to $OGMIOS_VERSION.
#   - target) Get the target ogmios version from the env file.
#   - current) Get the current ogmios version.
#   - check) Check if there is an update available from the current version.
#   - download) Download the ogmios binaries.
#   - install) Install the ogmios service and create directories.
#   - run) Run the ogmios service.
#   - start) Start the ogmios systemctl service.
#   - stop) Stop the ogmios systemctl service.
#   - restart) Restart the ogmios systemctl service.
#   - watch) Watch the ogmios service logs.
#   - status) Display the ogmios service status.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../env"
source "$(dirname "$0")/common.sh"

# Private functions

_ogmios_die() {
    print 'ERROR' "$1" $red
    return 1
}

_ogmios_fail() {
    _ogmios_die "$1" || return 1
}

_require_warm_node() {
    if is_cold_device; then
        _ogmios_fail 'This command can not be run on a cold device'
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _ogmios_fail 'Operation cancelled' ;;
    esac
}

_extract_ogmios_release() {
    local filename="$1"
    local extract_dir="downloads/extract"

    remove_path "$extract_dir"
    mkdir -p "$extract_dir" || _ogmios_fail 'Could not create extract directory' || return 1
    unzip -q "downloads/$filename" -d "$extract_dir" || _ogmios_fail "Could not extract archive: $filename" || return 1
    if [ ! -f "$extract_dir/$OGMIOS_NAME" ]; then
        _ogmios_fail "Release archive missing $extract_dir/$OGMIOS_NAME" || return 1
    fi
    sudo cp -a "$extract_dir/$OGMIOS_NAME" "$BIN_PATH/$OGMIOS_NAME" || _ogmios_fail 'Could not install ogmios binary' || return 1
    sudo chmod +x "$BIN_PATH/$OGMIOS_NAME" || _ogmios_fail 'Could not set ogmios binary permissions' || return 1
    return 0
}

# Public functions

ogmios_download() {
    print 'INSTALL' "Downloading ogmios binaries"
    local filenames=($(ogmios_release_filenames)) || _ogmios_fail "Unsupported platform: $(platform)" || return 1
    local filename

    if download_release_file "$OGMIOS_REMOTE" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        _extract_ogmios_release "$filename" || return 1
        remove_path downloads
        "$OGMIOS" --version || _ogmios_fail 'Installed ogmios binary is not runnable' || return 1
        print 'INSTALL' "Ogmios binary moved to $BIN_PATH" $green
        return 0
    fi

    remove_path downloads
    _ogmios_fail "Unable to download ogmios binaries for $(platform)/$(platform_arch)" || return 1
}

ogmios_update_target_version() {
    echo $OGMIOS_VERSION
    return 0
}

ogmios_update_current_version() {
    echo "$($OGMIOS --version 2>/dev/null | awk '{print $2}' | sed 's/^v//')"
    return 0
}

ogmios_update_check_version() {
    local latest current
    latest=$(ogmios_update_target_version)
    current=$(ogmios_update_current_version)
    if [ "$current" == "$latest" ]; then
        print 'UPDATE' "Ogmios is already up to date (v$current)" $green
        return 1
    elif [ -z "$current" ] || [ -z "$latest" ]; then
        _ogmios_fail "Unable to read update versions [current:$current] [latest:$latest]" || return 1
    else
        echo $latest
        return 0
    fi
}

ogmios_update() {
    _require_warm_node || return 1
    local latest
    latest=$(ogmios_update_check_version) || return 1
    _confirm "Please confirm ogmios update to version: $latest?" || return 1
    ogmios_stop || return 1
    ogmios_download || return 1
    ogmios_restart || return 1
    "$OGMIOS" --version || _ogmios_fail 'Installed ogmios binary is not runnable' || return 1
    print 'UPDATE' "Ogmios updated and restarted" $green
    return 0
}

ogmios_install() {
    print 'INSTALL' "Creating directories at $OGMIOS_PATH"
    mkdir -p $OGMIOS_PATH || _ogmios_fail 'Could not create ogmios directories' || return 1

    print 'INSTALL' 'Creating ogmios service'
    cp -p "$SERVICES_SOURCE/ogmios.service" "$SERVICES_SOURCE/$OGMIOS_NAME.temp"
    sed -i "$SERVICES_SOURCE/$OGMIOS_NAME.temp" \
        -e "s|NODE_HOME|$NODE_HOME|g" \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|OGMIOS_SERVICE|$OGMIOS_SERVICE|g"
    sudo cp -p "$SERVICES_SOURCE/$OGMIOS_NAME.temp" "$SERVICE_PATH/$OGMIOS_SERVICE" || _ogmios_fail 'Could not install ogmios service' || return 1
    rm "$SERVICES_SOURCE/$OGMIOS_NAME.temp"

    sudo systemctl daemon-reload || _ogmios_fail 'Could not reload systemd' || return 1
    sudo systemctl enable $OGMIOS_SERVICE || _ogmios_fail 'Could not enable ogmios service' || return 1
    print 'INSTALL' "Ogmios installed and enabled" $green
    return 0
}

ogmios_run() {
    $OGMIOS \
        --host "$OGMIOS_HOST" \
        --port "$OGMIOS_PORT" \
        --node-socket "$NETWORK_SOCKET_PATH" \
        --node-config "$NETWORK_PATH/config.json" \
        --data-dir "$OGMIOS_PATH"
}

ogmios_start() {
    _require_warm_node || return 1
    sudo systemctl start $OGMIOS_SERVICE || _ogmios_fail 'Could not start ogmios service' || return 1
    print 'NODE' "Ogmios service started" $green
    return 0
}

ogmios_stop() {
    _require_warm_node || return 1
    sudo systemctl stop $OGMIOS_SERVICE || _ogmios_fail 'Could not stop ogmios service' || return 1
    print 'NODE' "Ogmios service stopped" $green
    return 0
}

ogmios_restart() {
    _require_warm_node || return 1
    sudo systemctl restart $OGMIOS_SERVICE || _ogmios_fail 'Could not restart ogmios service' || return 1
    print 'NODE' "Ogmios service restarted" $green
    return 0
}

ogmios_watch() {
    _require_warm_node || return 1
    journalctl -u $OGMIOS_SERVICE -f -o cat
}

ogmios_status() {
    _require_warm_node || return 1
    sudo systemctl status $OGMIOS_SERVICE
}

case $1 in
    update) ogmios_update ;;
    target) ogmios_update_target_version ;;
    current) ogmios_update_current_version ;;
    check) ogmios_update_check_version ;;
    download) ogmios_download ;;
    install) ogmios_install ;;
    run) ogmios_run ;;
    start) ogmios_start ;;
    stop) ogmios_stop ;;
    restart) ogmios_restart ;;
    watch) ogmios_watch ;;
    status) ogmios_status ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
