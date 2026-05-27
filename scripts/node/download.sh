#!/bin/bash
# Usage: node/download.sh (
#   download |
#   node |
#   path |
#   help [-h]
# )
#
# Info:
#
#   - download) Download node binaries from IntersectMBO releases. Default value if no options are passed.
#   - node) Download node binaries from IntersectMBO releases.
#   - path) Set $BIN_PATH permissions and check if its in the $PATH.
#   - help) View this files help.

source "$(dirname "$0")/../common.sh"

# Private functions

_download_die() {
    print 'ERROR' "$1" $red
    return 1
}

_download_fail() {
    _download_die "$1" || return 1
}

_extract_cardano_node_release() {
    local filename="$1"
    local extract_dir="downloads/extract"

    remove_path "$extract_dir"
    mkdir -p "$extract_dir" || _download_fail 'Could not create extract directory' || return 1

    case "$filename" in
        *.zip)
            unzip -q "downloads/$filename" -d "$extract_dir" || _download_fail "Could not extract archive: $filename" || return 1
            ;;
        *.tar.gz)
            tar -xvzf "downloads/$filename" -C "$extract_dir" || _download_fail "Could not extract archive: $filename" || return 1
            ;;
        *)
            _download_fail "Unsupported release archive: $filename" || return 1
            ;;
    esac

    cp -a "$extract_dir/bin/." "$BIN_PATH/" || _download_fail 'Could not copy node binaries to bin path' || return 1
    return 0
}

# Public functions

download_node() {
    if [[ "$(platform_arch)" == "arm64" ]] && ! version_ge "$NODE_VERSION" "10.6.2"; then
        _download_fail "Node version $NODE_VERSION has no arm64 release. Set NODE_VERSION to 10.6.2 or later." || return 1
    fi
    print 'DOWNLOAD' "Downloading node binaries from IntersectMBO releases"
    local filenames=($(cardano_node_release_filenames)) || _download_fail "Unsupported platform: $(platform)" || return 1
    local filename

    if download_release_file "$NODE_REMOTE" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        _extract_cardano_node_release "$filename" || return 1
        remove_path downloads
        print 'DOWNLOAD' "Node binaries moved to $BIN_PATH" $green
        return 0
    fi

    remove_path downloads
    _download_fail "Unable to download binaries for $(platform)/$(platform_arch)" || return 1
}

download_set_path() {
    print 'DOWNLOAD' "Creating bin path and setting download permissions"
    chmod +x -R "$BIN_PATH" || _download_fail 'Could not set bin path permissions' || return 1
    if [[ "$PATH" != *"$HOME/local/bin/"* ]]; then
        sed -i '$ a\export PATH="$PATH:$HOME/local/bin/"' ~/.bashrc || _download_fail 'Could not update PATH in bashrc' || return 1
    fi
    source ~/.bashrc
    print 'DOWNLOAD' "Bin path and permissions set" $green
    return 0
}

download() {
    download_node || return 1
    download_set_path || return 1
    return 0
}

case $1 in
    download) download ;;
    node) download_node ;;
    path) download_set_path ;;
    help) help "${2:-"--help"}" ;;
    *) download ;;
esac
exit $?
