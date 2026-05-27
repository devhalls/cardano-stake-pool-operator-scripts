#!/bin/bash
# Usage: dbsync.sh [
#   dependencies |
#   download |
#   install |
#   snapshot_download |
#   snapshot_process |
#   snapshot_restore |
#   run |
#   start |
#   stop |
#   restart |
#   watch |
#   status |
#   create |
#   drop |
#   view |
#   help [?-h]
# ]
#
# Info:
#
#   - dependencies) Install db sync dependencies, eg postgresql. Creates a new pg user $POSTGRES_USER.
#   - download) Download the db sync binaries.
#   - install) Install the db sync service and create directories.
#   - snapshot_download) Download the db sync snapshot from $DB_SYNC_PG_SNAPSHOT.
#   - snapshot_process) Processes the db sync snapshot zip archive preparing for import.
#   - snapshot_restore) Restore db sync snapshot.
#   - run) Run the db sync service.
#   - start) Start the db-sync systemctl service.
#   - stop) Stop the db-sync systemctl service.
#   - restart) Restart the db-sync systemctl service.
#   - watch) Watch the db-sync service logs.
#   - status) Display the db-sync service status.
#   - create) ...
#   - drop) ...
#   - view) ...
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../env"
source "$(dirname "$0")/common.sh"

dbsync_dependencies() {
    sudo $PACKAGER install postgresql postgresql-contrib -y
    sudo -u postgres createuser -d -r -s $POSTGRES_USER
    sudo -u postgres createuser -d -r -s $NODE_USER
}

dbsync_download() {
    require_dbsync_arm64_support
    print 'INSTALL' "Downloading db-sync binaries"
    local filenames=($(dbsync_release_filenames))
    local filename remote="${DB_SYNC_REMOTE}/${DB_SYNC_VERSION}"
    local extract_dir="downloads/extract"

    if download_release_file "$remote" "${filenames[@]}"; then
        filename=$DOWNLOAD_RELEASE_FILENAME
        rm -rf "$extract_dir"
        mkdir -p "$extract_dir"
        tar -xvzf "downloads/$filename" -C "$extract_dir"
        sudo cp -a "$extract_dir/." $BIN_PATH/
        chmod +x -R $BIN_PATH
        rm -R downloads
        $DB_SYNC_NAME --version
        print 'INSTALL' "DBSync binaries moved to $BIN_PATH" $green
    else
        rm -R downloads
        print 'ERROR' "Unable to download db-sync binaries for $(platform)/$(platform_arch)" $red
        exit 1
    fi
}

dbsync_install() {
    print 'INSTALL' "Creating directories at $DB_SYNC_PATH"
    mkdir -p $DB_SYNC_PATH $DB_SYNC_PATH/schema $DB_SYNC_PATH/ledger-state
    cp -pr services/schema/. $DB_SYNC_PATH/schema
    cp -p services/pgpass services/pgpass.temp
    sed -i services/pgpass.temp \
        -e "s|POSTGRES_DB|$POSTGRES_DB|g"
    cp -p services/pgpass.temp $DB_SYNC_PATH/pgpass

    print 'INSTALL' 'Creating db-sync service'
    cp -p services/cardano-db-sync.service services/$DB_SYNC_NAME.temp
    sed -i services/$DB_SYNC_NAME.temp \
        -e "s|NODE_HOME|$NODE_HOME|g" \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|DB_SYNC_SERVICE|$DB_SYNC_SERVICE|g"
    sudo cp -p services/$DB_SYNC_NAME.temp $SERVICE_PATH/$DB_SYNC_SERVICE
    rm services/$DB_SYNC_NAME.temp

    sudo systemctl daemon-reload
    sudo systemctl enable $DB_SYNC_SERVICE
    print 'INSTALL' "DB-sync installed and enabled" $green
}

dbsync_snapshot_download() {
    cd $DB_SYNC_PATH && {
                        curl -O $DB_SYNC_PG_SNAPSHOT
                                                       cd -
    }
    if [ $? -eq 0 ]; then
        print 'INSTALL' "Snapshot downloaded to $DB_SYNC_PATH" $green
    else
        print 'ERROR' "Unable to download snapshot" $red
        exit 1
    fi
}

dbsync_snapshot_process() {
    print 'INSTALL' "Processing snapshot archive ..."
    if test -d "$tmpDir/db/"; then
        print 'ERROR' "Import snapshot/db directory already exists" $red
    fi
    local fileName=$(echo $DB_SYNC_PG_SNAPSHOT | awk -F'/' '{print $NF}')
    local tmpDir=$DB_SYNC_PATH/snapshot
    mkdir -p $tmpDir
    tar -xvf "$DB_SYNC_PATH/$fileName" -C "$tmpDir"
    if test -d "$tmpDir/db/"; then
        print 'INSTALL' "Snapshot imported" $green
        return 0
    fi
    print 'ERROR' "Unable to import snapshot" $red
}

dbsync_snapshot_restore() {
    cores=$(getconf _NPROCESSORS_ONLN)
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
            "$DB_SYNC_PATH/snapshot/db/"
        return 0
    fi
    print 'ERROR' "Unable to import snapshot, no " $red
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
    exit_if_cold
    sudo systemctl start $DB_SYNC_SERVICE
    print 'NODE' "DBSync service started" $green
}

dbsync_stop() {
    exit_if_cold
    sudo systemctl stop $DB_SYNC_SERVICE
    print 'NODE' "DBSync service stopped" $green
}

dbsync_restart() {
    exit_if_cold
    sudo systemctl restart $DB_SYNC_SERVICE
    print 'NODE' "DBSync service restarted" $green
}

dbsync_watch() {
    exit_if_cold
    journalctl -u $DB_SYNC_SERVICE -f -o cat
}

dbsync_status() {
    exit_if_cold
    sudo systemctl status $DB_SYNC_SERVICE
}

dbsync_create_db() {
    createdb -T template0 --owner="${POSTGRES_USER}" --encoding=UTF8 "${POSTGRES_DB}"
}

dbsync_drop_db() {
    dropdb -f $POSTGRES_DB
}

dbsync_view_db() {
    psql "${POSTGRES_DB}" \
        --command="select table_name from information_schema.views where table_catalog = '${POSTGRES_DB}' and table_schema = 'public' ;"
}

dbsync_get_block() {
    latest_block=$(psql "$POSTGRES_DB" -t -A -c "SELECT * FROM block;" 2>/dev/null)
    if [[ $? -eq 0 && "$latest_block" =~ ^[0-9]+$ ]]; then
        echo $latest_block
    else
        echo ""
    fi
}

case $1 in
    dependencies) dbsync_dependencies ;;
    download) dbsync_download ;;
    install) dbsync_install ;;
    snapshot) dbsync_snapshot_download ;;
    process) dbsync_snapshot_process ;;
    import) dbsync_snapshot_import ;;
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
