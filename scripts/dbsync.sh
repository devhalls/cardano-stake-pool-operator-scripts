#!/bin/bash
# Usage: dbsync.sh (
#   update |
#   target |
#   current |
#   check |
#   dependencies |
#   download |
#   install |
#   snapshot |
#   process |
#   import |
#   run |
#   start |
#   stop |
#   restart |
#   watch |
#   status |
#   create |
#   drop |
#   view |
#   get_block |
#   help [-h]
# )
#
# Info:
#
#   - update) Updates db-sync to $DB_SYNC_VERSION.
#   - target) Get the target db-sync version from the env file.
#   - current) Get the current db-sync version.
#   - check) Check if there is an update available from the current version.
#   - dependencies) Install db sync dependencies, eg postgresql. Creates a new pg user $POSTGRES_USER.
#   - download) Download the db sync binaries.
#   - install) Install the db sync service and create directories.
#   - snapshot) Download the db sync snapshot from $DB_SYNC_PG_SNAPSHOT.
#   - process) Process the db sync snapshot zip archive preparing for import.
#   - import) Restore db sync snapshot.
#   - run) Run the db sync service.
#   - start) Start the db-sync systemctl service.
#   - stop) Stop the db-sync systemctl service.
#   - restart) Restart the db-sync systemctl service.
#   - watch) Watch the db-sync service logs.
#   - status) Display the db-sync service status.
#   - create) Create the db-sync postgres database.
#   - drop) Drop the db-sync postgres database.
#   - view) List db-sync postgres views.
#   - get_block) Get the latest block number from the db-sync database.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../env"
source "$(dirname "$0")/common.sh"

# Private functions

_dbsync_die() {
    print 'ERROR' "$1" $red
    return 1
}

_dbsync_fail() {
    _dbsync_die "$1" || return 1
}

_require_warm_node() {
    if is_cold_device; then
        _dbsync_fail 'This command can not be run on a cold device'
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _dbsync_fail 'Operation cancelled' ;;
    esac
}

# Public functions

dbsync_dependencies() {
    sudo $PACKAGER install postgresql postgresql-contrib -y || _dbsync_fail 'Could not install postgresql' || return 1
    sudo -u postgres createuser -d -r -s $POSTGRES_USER || _dbsync_fail 'Could not create postgres user' || return 1
    sudo -u postgres createuser -d -r -s $NODE_USER || _dbsync_fail 'Could not create node postgres user' || return 1
    return 0
}

dbsync_download() {
    require_dbsync_arm64_support
    print 'INSTALL' "Downloading db-sync binaries"
    local filenames=($(dbsync_release_filenames))
    local filename remote="${DB_SYNC_REMOTE}/${DB_SYNC_VERSION}"
    local extract_dir="downloads/extract"

    if download_release_file "$remote" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        remove_path "$extract_dir"
        mkdir -p "$extract_dir"
        tar -xvzf "downloads/$filename" -C "$extract_dir" || _dbsync_fail 'Could not extract db-sync archive' || return 1
        sudo cp -a "$extract_dir/." $BIN_PATH/ || _dbsync_fail 'Could not install db-sync binaries' || return 1
        chmod +x -R $BIN_PATH
        remove_path downloads
        $DB_SYNC_NAME --version
        print 'INSTALL' "DBSync binaries moved to $BIN_PATH" $green
        return 0
    fi

    remove_path downloads
    _dbsync_fail "Unable to download db-sync binaries for $(platform)/$(platform_arch)" || return 1
}

dbsync_update_target_version() {
    echo $DB_SYNC_VERSION
    return 0
}

dbsync_update_current_version() {
    echo "$($DB_SYNC --version 2>/dev/null | awk '{print $2}')"
    return 0
}

dbsync_update_check_version() {
    local latest current
    latest=$(dbsync_update_target_version)
    current=$(dbsync_update_current_version)
    if [ "$current" == "$latest" ]; then
        print 'UPDATE' "DB-sync is already up to date (v$current)" $green
        return 1
    elif [ -z "$current" ] || [ -z "$latest" ]; then
        _dbsync_fail "Unable to read update versions [current:$current] [latest:$latest]" || return 1
    else
        echo $latest
        return 0
    fi
}

dbsync_update() {
    _require_warm_node || return 1
    local latest
    latest=$(dbsync_update_check_version) || return 1
    _confirm "Please confirm db-sync update to version: $latest?" || return 1
    dbsync_stop || return 1
    dbsync_download || return 1
    dbsync_restart || return 1
    $DB_SYNC --version || _dbsync_fail 'Installed db-sync binary is not runnable' || return 1
    print 'UPDATE' "DB-sync updated and restarted" $green
    return 0
}

dbsync_install() {
    print 'INSTALL' "Creating directories at $DB_SYNC_PATH"
    mkdir -p $DB_SYNC_PATH $DB_SYNC_PATH/schema $DB_SYNC_PATH/ledger-state || _dbsync_fail 'Could not create db-sync directories' || return 1
    cp -pr services/schema/. $DB_SYNC_PATH/schema || _dbsync_fail 'Could not copy db-sync schema' || return 1
    cp -p services/pgpass services/pgpass.temp
    sed -i services/pgpass.temp \
        -e "s|POSTGRES_DB|$POSTGRES_DB|g"
    cp -p services/pgpass.temp $DB_SYNC_PATH/pgpass || _dbsync_fail 'Could not create pgpass file' || return 1

    print 'INSTALL' 'Creating db-sync service'
    cp -p services/cardano-db-sync.service services/$DB_SYNC_NAME.temp
    sed -i services/$DB_SYNC_NAME.temp \
        -e "s|NODE_HOME|$NODE_HOME|g" \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|DB_SYNC_SERVICE|$DB_SYNC_SERVICE|g"
    sudo cp -p services/$DB_SYNC_NAME.temp $SERVICE_PATH/$DB_SYNC_SERVICE || _dbsync_fail 'Could not install db-sync service' || return 1
    rm services/$DB_SYNC_NAME.temp

    sudo systemctl daemon-reload || _dbsync_fail 'Could not reload systemd' || return 1
    sudo systemctl enable $DB_SYNC_SERVICE || _dbsync_fail 'Could not enable db-sync service' || return 1
    print 'INSTALL' "DB-sync installed and enabled" $green
    return 0
}

dbsync_snapshot_download() {
    cd $DB_SYNC_PATH && curl -O $DB_SYNC_PG_SNAPSHOT && cd - || _dbsync_fail 'Unable to download snapshot' || return 1
    print 'INSTALL' "Snapshot downloaded to $DB_SYNC_PATH" $green
    return 0
}

dbsync_snapshot_process() {
    print 'INSTALL' "Processing snapshot archive ..."
    local fileName=$(echo $DB_SYNC_PG_SNAPSHOT | awk -F'/' '{print $NF}')
    local tmpDir=$DB_SYNC_PATH/snapshot
    if test -d "$tmpDir/db/"; then
        _dbsync_fail 'Import snapshot/db directory already exists' || return 1
    fi
    mkdir -p $tmpDir || _dbsync_fail 'Could not create snapshot directory' || return 1
    tar -xvf "$DB_SYNC_PATH/$fileName" -C "$tmpDir" || _dbsync_fail 'Unable to extract snapshot archive' || return 1
    if test -d "$tmpDir/db/"; then
        print 'INSTALL' "Snapshot processed" $green
        return 0
    fi
    _dbsync_fail 'Unable to process snapshot' || return 1
}

dbsync_snapshot_restore() {
    local cores=$(getconf _NPROCESSORS_ONLN)
    if test "${cores}" -le 2; then
        cores=1
    else
        cores=$((cores - 1))
    fi
    if test -d "$DB_SYNC_PATH/snapshot/db/"; then
        pg_restore \
            --schema=public \
            --format=directory \
            --dbname="$POSTGRES_DB" \
            --jobs="$cores" \
            --exit-on-error \
            --no-owner \
            "$DB_SYNC_PATH/snapshot/db/" || _dbsync_fail 'Unable to restore snapshot' || return 1
        return 0
    fi
    _dbsync_fail 'Unable to import snapshot, snapshot/db directory not found' || return 1
}

dbsync_run() {
    export PGPASSFILE=$DB_SYNC_PATH/pgpass
    local rollbackSlot
    if [[ "$DB_SYNC_ROLLBACK_SLOT" =~ ^[0-9]+$ ]]; then
        rollbackSlot="--rollback-to-slot $DB_SYNC_ROLLBACK_SLOT"
    fi
    $DB_SYNC \
        --config $NETWORK_PATH/db-sync-config.json \
        --socket-path $NETWORK_SOCKET_PATH \
        --state-dir $DB_SYNC_PATH/ledger-state \
        --schema-dir $DB_SYNC_PATH/schema/ \
        $rollbackSlot
}

dbsync_start() {
    _require_warm_node || return 1
    sudo systemctl start $DB_SYNC_SERVICE || _dbsync_fail 'Could not start db-sync service' || return 1
    print 'NODE' "DBSync service started" $green
    return 0
}

dbsync_stop() {
    _require_warm_node || return 1
    sudo systemctl stop $DB_SYNC_SERVICE || _dbsync_fail 'Could not stop db-sync service' || return 1
    print 'NODE' "DBSync service stopped" $green
    return 0
}

dbsync_restart() {
    _require_warm_node || return 1
    sudo systemctl restart $DB_SYNC_SERVICE || _dbsync_fail 'Could not restart db-sync service' || return 1
    print 'NODE' "DBSync service restarted" $green
    return 0
}

dbsync_watch() {
    _require_warm_node || return 1
    journalctl -u $DB_SYNC_SERVICE -f -o cat
}

dbsync_status() {
    _require_warm_node || return 1
    sudo systemctl status $DB_SYNC_SERVICE
}

dbsync_create_db() {
    createdb -T template0 --owner="${POSTGRES_USER}" --encoding=UTF8 "${POSTGRES_DB}" || _dbsync_fail 'Could not create database' || return 1
    return 0
}

dbsync_drop_db() {
    dropdb -f $POSTGRES_DB || _dbsync_fail 'Could not drop database' || return 1
    return 0
}

dbsync_view_db() {
    psql "${POSTGRES_DB}" \
        --command="select table_name from information_schema.views where table_catalog = '${POSTGRES_DB}' and table_schema = 'public' ;"
    return $?
}

dbsync_get_block() {
    local latest_block
    latest_block=$(psql "$POSTGRES_DB" -t -A -c "SELECT * FROM block;" 2>/dev/null)
    if [[ $? -eq 0 && "$latest_block" =~ ^[0-9]+$ ]]; then
        echo $latest_block
        return 0
    fi
    echo ""
    return 0
}

case $1 in
    update) dbsync_update ;;
    target) dbsync_update_target_version ;;
    current) dbsync_update_current_version ;;
    check) dbsync_update_check_version ;;
    dependencies) dbsync_dependencies ;;
    download) dbsync_download ;;
    install) dbsync_install ;;
    snapshot) dbsync_snapshot_download ;;
    process) dbsync_snapshot_process ;;
    import) dbsync_snapshot_restore ;;
    run) dbsync_run ;;
    start) dbsync_start ;;
    stop) dbsync_stop ;;
    restart) dbsync_restart ;;
    watch) dbsync_watch ;;
    status) dbsync_status ;;
    create) dbsync_create_db ;;
    drop) dbsync_drop_db ;;
    view) dbsync_view_db ;;
    get_block) dbsync_get_block ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
