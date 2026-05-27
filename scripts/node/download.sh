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

extract_cardano_node_release() {
    local filename="$1"
    local extract_dir="downloads/extract"

    remove_path "$extract_dir"
    mkdir -p "$extract_dir"

    case "$filename" in
        *.zip)
            unzip -q "downloads/$filename" -d "$extract_dir"
            ;;
        *.tar.gz)
            tar -xvzf "downloads/$filename" -C "$extract_dir"
            ;;
        *)
            print 'ERROR' "Unsupported release archive: $filename" $red
            return 1
            ;;
    esac

    cp -a "$extract_dir/bin/." "$BIN_PATH/"
}

download_node() {
    require_cardano_node_arm64_version
    print 'DOWNLOAD' "Downloading node binaries from IntersectMBO releases"
    local filenames=($(cardano_node_release_filenames))
    local filename

    if download_release_file "$NODE_REMOTE" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        extract_cardano_node_release "$filename"
        remove_path downloads
        print 'DOWNLOAD' "Node binaries moved to $BIN_PATH" $green
        return 0
    fi

    remove_path downloads
    print 'ERROR' "Unable to download binaries for $(platform)/$(platform_arch)" $red
    exit 1
}

download_set_path() {
    print 'DOWNLOAD' "Creating bin path and setting download permissions"
    chmod +x -R $BIN_PATH
    if [[ "$PATH" != *"$HOME/local/bin/"* ]]; then
        sed -i '$ a\export PATH="$PATH:$HOME/local/bin/"' ~/.bashrc
    fi
    source ~/.bashrc
    print 'DOWNLOAD' "Bin path and permissions set" $green
}

download() {
    download_node
    download_set_path
}

case $1 in
    download) download ;;
    node) download_node ;;
    path) download_set_path ;;
    help) help "${2:-"--help"}" ;;
    *) download ;;
esac
