#!/bin/bash
# Usage: node/update.sh (
#   update |
#   configs |
#   target |
#   current |
#   check |
#   binaries |
#   build [...params] |
#   download [...params] |
#   help [-h]
# )
#
# Info:
#
#   - update) Updates a cardano node to $NODE_VERSION. Default value if no options are passed.
#   - configs) Sync node config files from the repo (overwrites bundled files).
#   - target) Get the target cardano node version from the env file.
#   - current) Get the current node version.
#   - check) Check if there is an update available from the current version.
#   - binaries) Build or download the node binaries based on $NODE_BUILD.
#   - build) Build the node binaries from source.
#   - download) Download the node binaries.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../common.sh"

# Private functions

_update_die() {
    print 'ERROR' "$1" $red
    return 1
}

_update_fail() {
    _update_die "$1" || return 1
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _update_fail 'Update cancelled' ;;
    esac
}

# Public functions

update_target_version() {
    echo $NODE_VERSION
    return 0
}

update_current_version() {
    echo "$(cardano_node_version)"
    return 0
}

update_check_version() {
    local latest current
    latest=$(update_target_version)
    current=$(update_current_version)
    if [ "$current" == "$latest" ]; then
        print 'UPDATE' "Cardano node is already up to date (v$current)" $green
        return 1
    elif [ -z "$current" ] || [ -z "$latest" ]; then
        _update_fail "Unable to read update versions [current:$current] [latest:$latest]" || return 1
    else
        echo $latest
        return 0
    fi
}

update_binaries() {
    print 'UPDATE' 'Installing node binaries'
    if [[ $NODE_BUILD == 1 ]]; then
        bash "$(dirname "$0")/download.sh" download || _update_fail 'Binary download failed' || return 1
    elif [[ $NODE_BUILD == 2 ]]; then
        bash "$(dirname "$0")/build.sh" build || _update_fail 'Binary build failed' || return 1
    else
        print 'UPDATE' 'Node binaries skipped' $green
    fi
    return 0
}

update_configs() {
    bash "$(dirname "$0")/install.sh" configs || return 1
    print 'UPDATE' "Node configs synced from $CONFIG_SOURCE" $green
    print 'UPDATE' "Restart the node to apply: scripts/node.sh restart" $orange
    return 0
}

update() {
    local latest
    latest=$(update_check_version) || return 1
    _confirm "Please confirm update to the new version: $latest?" || return 1
    bash "$(dirname "$0")/../node.sh" stop || _update_fail 'Could not stop node service' || return 1
    update_binaries || return 1
    bash "$(dirname "$0")/../node.sh" restart || _update_fail 'Could not restart node service' || return 1
    source ~/.bashrc
    $CNNODE --version || _update_fail 'Installed cardano-node binary is not runnable' || return 1
    $CNCLI --version || _update_fail 'Installed cardano-cli binary is not runnable' || return 1
    print 'UPDATE' "Node updated and restarted" $green
    return 0
}

case $1 in
    update) update "$@" ;;
    configs) update_configs ;;
    check) update_check_version ;;
    target) update_target_version ;;
    current) update_current_version ;;
    binaries) update_binaries ;;
    build) bash "$(dirname "$0")/build.sh" "${@:2}" ;;
    download) bash "$(dirname "$0")/download.sh" "${@:2}" ;;
    help) help "${2:-"--help"}" ;;
    *) update "$@" ;;
esac
exit $?
