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
#   export |
#   restore |
#   export-state |
#   import-state |
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
#   import-status |
#   watch-import |
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
#   - snapshot) Download the db sync snapshot from $POSTGRES_SNAPSHOT.
#   - process) Process the db sync snapshot zip archive preparing for import.
#   - import) Restore db sync snapshot from $DB_SYNC_PATH/snapshot/db/.
#   - export) Dump the live db-sync database to $DB_SYNC_PATH/migration/db/ for migration.
#   - restore) Restore a db-sync database from $DB_SYNC_PATH/migration/db/ (or snapshot/db/).
#   - export-state) Archive $DB_SYNC_PATH/ledger-state for migration.
#   - import-state) Restore ledger-state from $DB_SYNC_PATH/migration/ledger-state.tar.gz.
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
#   - import-status) Show pg_restore activity and database size during snapshot import.
#   - watch-import) Poll import-status every 30s until Ctrl+C (import runs elsewhere).
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

_dbsync_pgpass() {
    export PGPASSFILE=$DB_SYNC_PATH/pgpass
    if [ -f "$PGPASSFILE" ]; then
        chmod 600 "$PGPASSFILE" 2>/dev/null || true
    fi
}

_dbsync_restore_jobs() {
    local cores
    cores=$(getconf _NPROCESSORS_ONLN)
    if test "${cores}" -le 2; then
        echo 1
    else
        echo $((cores - 1))
    fi
}

_dbsync_restore_directory() {
    local dump_dir="$1"
    local jobs
    jobs=$(_dbsync_restore_jobs)
    _dbsync_pgpass
    print 'INSTALL' "pg_restore from $dump_dir using $jobs parallel job(s) (verbose log below) ..."
    pg_restore \
        --schema=public \
        --format=directory \
        --dbname="$POSTGRES_DB" \
        --jobs="$jobs" \
        --exit-on-error \
        --no-owner \
        --verbose \
        "$dump_dir" || _dbsync_fail "Unable to restore database from $dump_dir" || return 1
    return 0
}

_dbsync_migration_manifest_write() {
    local migration_dir="$DB_SYNC_PATH/migration"
    mkdir -p "$migration_dir" || _dbsync_fail 'Could not create migration directory' || return 1
    _dbsync_pgpass
    cat >"$migration_dir/manifest.txt" <<EOF
DB_SYNC_VERSION=$(dbsync_update_current_version)
POSTGRES_DB=$POSTGRES_DB
NODE_NETWORK=$NODE_NETWORK
BLOCK=$(dbsync_get_block)
EXPORT_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
    return 0
}

_dbsync_migration_manifest_check() {
    local manifest="$DB_SYNC_PATH/migration/manifest.txt"
    local exported_version current_version exported_db exported_block
    if [ ! -f "$manifest" ]; then
        print 'MIGRATE' 'No migration manifest found (skipping version check)' $orange
        return 0
    fi
    exported_version=$(grep '^DB_SYNC_VERSION=' "$manifest" | cut -d= -f2-)
    exported_db=$(grep '^POSTGRES_DB=' "$manifest" | cut -d= -f2-)
    current_version=$(dbsync_update_current_version)
    if [ -n "$exported_version" ] && [ -n "$current_version" ] && [ "$exported_version" != "$current_version" ]; then
        _dbsync_fail "DB-sync version mismatch [exported:$exported_version] [current:$current_version]" || return 1
    fi
    if [ -n "$exported_db" ] && [ "$exported_db" != "$POSTGRES_DB" ]; then
        print 'MIGRATE' "Database name differs [exported:$exported_db] [current:$POSTGRES_DB]" $orange
    fi
    exported_block=$(grep '^BLOCK=' "$manifest" | cut -d= -f2-)
    if [ -n "$exported_block" ]; then
        print 'MIGRATE' "Exported at block $exported_block" $green
    fi
    return 0
}

_dbsync_ensure_postgres_role() {
    local role=$1
    if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${role}'" 2>/dev/null | grep -q 1; then
        print 'INSTALL' "Postgres role already exists: ${role}"
        return 0
    fi
    sudo -u postgres createuser -d -r -s "$role" || _dbsync_fail "Could not create postgres role: ${role}" || return 1
}

# Public functions

dbsync_dependencies() {
    sudo $PACKAGER install postgresql postgresql-contrib -y || _dbsync_fail 'Could not install postgresql' || return 1
    _dbsync_ensure_postgres_role "$POSTGRES_USER" || return 1
    _dbsync_ensure_postgres_role "$NODE_USER" || return 1
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
        tar -xzf "downloads/$filename" -C "$extract_dir" || _dbsync_fail 'Could not extract db-sync archive' || return 1
        if [ ! -f "$extract_dir/bin/$DB_SYNC_NAME" ]; then
            _dbsync_fail "Release archive missing $extract_dir/bin/$DB_SYNC_NAME" || return 1
        fi
        sudo cp -a "$extract_dir/bin/." "$BIN_PATH/" || _dbsync_fail 'Could not install db-sync binaries' || return 1
        sudo chmod +x "$BIN_PATH"/* 2>/dev/null || true
        sudo rm -rf downloads
        "$DB_SYNC" --version || _dbsync_fail 'Installed db-sync binary is not runnable' || return 1
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
    cp -pr "$SCHEMA_SOURCE/." "$DB_SYNC_PATH/schema" || _dbsync_fail 'Could not copy db-sync schema' || return 1
    cp -p "$SERVICES_SOURCE/pgpass" "$SERVICES_SOURCE/pgpass.temp"
    sed -i "$SERVICES_SOURCE/pgpass.temp" \
        -e "s|POSTGRES_DB|$POSTGRES_DB|g"
    cp -p "$SERVICES_SOURCE/pgpass.temp" "$DB_SYNC_PATH/pgpass" || _dbsync_fail 'Could not create pgpass file' || return 1
    rm -f "$SERVICES_SOURCE/pgpass.temp"
    chmod 600 "$DB_SYNC_PATH/pgpass" || _dbsync_fail 'Could not set pgpass permissions' || return 1

    print 'INSTALL' 'Creating db-sync service'
    cp -p "$SERVICES_SOURCE/cardano-db-sync.service" "$SERVICES_SOURCE/$DB_SYNC_NAME.temp"
    sed -i "$SERVICES_SOURCE/$DB_SYNC_NAME.temp" \
        -e "s|NODE_HOME|$NODE_HOME|g" \
        -e "s|NODE_USER|$NODE_USER|g" \
        -e "s|DB_SYNC_SERVICE|$DB_SYNC_SERVICE|g"
    sudo cp -p "$SERVICES_SOURCE/$DB_SYNC_NAME.temp" "$SERVICE_PATH/$DB_SYNC_SERVICE" || _dbsync_fail 'Could not install db-sync service' || return 1
    rm "$SERVICES_SOURCE/$DB_SYNC_NAME.temp"

    sudo systemctl daemon-reload || _dbsync_fail 'Could not reload systemd' || return 1
    sudo systemctl enable $DB_SYNC_SERVICE || _dbsync_fail 'Could not enable db-sync service' || return 1
    print 'INSTALL' "DB-sync installed and enabled" $green
    return 0
}

dbsync_snapshot_download() {
    local fileName dest
    fileName=$(echo "$POSTGRES_SNAPSHOT" | awk -F'/' '{print $NF}')
    mkdir -p "$DB_SYNC_PATH" || _dbsync_fail 'Could not create db-sync path' || return 1
    dest="$DB_SYNC_PATH/$fileName"
    print 'INSTALL' "Downloading snapshot to $dest"
    print 'INSTALL' 'Large IOG snapshots often drop mid-transfer; re-run snapshot to resume' $orange
    if command -v wget >/dev/null 2>&1; then
        wget -c -O "$dest" "$POSTGRES_SNAPSHOT" || _dbsync_fail 'Unable to download snapshot' || return 1
    else
        curl -C - -L -f \
            --retry 50 --retry-all-errors --retry-delay 10 \
            -o "$dest" "$POSTGRES_SNAPSHOT" || _dbsync_fail 'Unable to download snapshot' || return 1
    fi
    print 'INSTALL' "Snapshot downloaded to $dest" $green
    return 0
}

dbsync_snapshot_process() {
    print 'INSTALL' "Processing snapshot archive ..."
    local fileName=$(echo $POSTGRES_SNAPSHOT | awk -F'/' '{print $NF}')
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
    if test -d "$DB_SYNC_PATH/snapshot/db/"; then
        print 'INSTALL' "Restoring $POSTGRES_DB from IOG snapshot (often several hours on mainnet)"
        print 'INSTALL' 'Open another SSH session and run: scripts/dbsync.sh watch-import' $orange
        _dbsync_restore_directory "$DB_SYNC_PATH/snapshot/db/" || return 1
        print 'INSTALL' "Snapshot import finished for $POSTGRES_DB" $green
        return 0
    fi
    _dbsync_fail 'Unable to import snapshot, snapshot/db directory not found' || return 1
}

dbsync_export_db() {
    _require_warm_node || return 1
    local migration_dir="$DB_SYNC_PATH/migration"
    local dump_dir="$migration_dir/db"
    local jobs
    jobs=$(_dbsync_restore_jobs)
    if test -d "$dump_dir/"; then
        _dbsync_fail "Export directory already exists: $dump_dir" || return 1
    fi
    mkdir -p "$dump_dir" || _dbsync_fail 'Could not create export directory' || return 1
    _dbsync_pgpass
    print 'MIGRATE' "Exporting $POSTGRES_DB to $dump_dir (this may take a while) ..."
    pg_dump \
        --format=directory \
        --dbname="$POSTGRES_DB" \
        --jobs="$jobs" \
        --no-owner \
        --file="$dump_dir" || _dbsync_fail 'Unable to export database' || return 1
    _dbsync_migration_manifest_write || return 1
    print 'MIGRATE' "Database exported to $dump_dir" $green
    return 0
}

dbsync_restore_db() {
    _require_warm_node || return 1
    local dump_dir="${1:-}"
    if [ -z "$dump_dir" ]; then
        if test -d "$DB_SYNC_PATH/migration/db/"; then
            dump_dir="$DB_SYNC_PATH/migration/db/"
        elif test -d "$DB_SYNC_PATH/snapshot/db/"; then
            dump_dir="$DB_SYNC_PATH/snapshot/db/"
        else
            _dbsync_fail 'No restore source found (expected migration/db/ or snapshot/db/)' || return 1
        fi
    elif [ ! -d "$dump_dir" ]; then
        _dbsync_fail "Restore source not found: $dump_dir" || return 1
    fi
    _dbsync_migration_manifest_check || return 1
    print 'MIGRATE' "Restoring $POSTGRES_DB from $dump_dir (this may take a while) ..."
    _dbsync_restore_directory "$dump_dir" || return 1
    print 'MIGRATE' "Database restored from $dump_dir" $green
    return 0
}

dbsync_export_state() {
    _require_warm_node || return 1
    local migration_dir="$DB_SYNC_PATH/migration"
    local archive="$migration_dir/ledger-state.tar.gz"
    if [ ! -d "$DB_SYNC_PATH/ledger-state" ]; then
        _dbsync_fail "Ledger state directory not found: $DB_SYNC_PATH/ledger-state" || return 1
    fi
    mkdir -p "$migration_dir" || _dbsync_fail 'Could not create migration directory' || return 1
    print 'MIGRATE' "Archiving ledger-state to $archive ..."
    tar -czf "$archive" -C "$DB_SYNC_PATH" ledger-state || _dbsync_fail 'Unable to archive ledger-state' || return 1
    print 'MIGRATE' "Ledger state archived to $archive" $green
    return 0
}

dbsync_import_state() {
    _require_warm_node || return 1
    local archive="$DB_SYNC_PATH/migration/ledger-state.tar.gz"
    if [ ! -f "$archive" ]; then
        _dbsync_fail "Ledger state archive not found: $archive" || return 1
    fi
    mkdir -p "$DB_SYNC_PATH" || _dbsync_fail 'Could not create db-sync path' || return 1
    print 'MIGRATE' "Restoring ledger-state from $archive ..."
    tar -xzf "$archive" -C "$DB_SYNC_PATH" || _dbsync_fail 'Unable to restore ledger-state' || return 1
    print 'MIGRATE' "Ledger state restored to $DB_SYNC_PATH/ledger-state" $green
    return 0
}

dbsync_run() {
    _dbsync_pgpass
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
    latest_block=$(psql "$POSTGRES_DB" -t -A -c "SELECT MAX(block_no) FROM block;" 2>/dev/null)
    if [[ $? -eq 0 && "$latest_block" =~ ^[0-9]+$ ]]; then
        echo $latest_block
        return 0
    fi
    echo ""
    return 0
}

dbsync_import_status() {
    _dbsync_pgpass
    local size workers
    if pgrep -u "$NODE_USER" -a pg_restore 2>/dev/null | grep -q pg_restore; then
        print 'INSTALL' 'pg_restore: running' $green
        workers=$(pgrep -u "$NODE_USER" -c pg_restore 2>/dev/null || echo 0)
        print 'INSTALL' "pg_restore worker processes: ${workers}"
    else
        print 'INSTALL' 'pg_restore: not running (finished, failed, or not started yet)'
    fi
    size=$(psql "$POSTGRES_DB" -tAc "SELECT pg_size_pretty(pg_database_size('${POSTGRES_DB}'));" 2>/dev/null) || size='(unavailable)'
    print 'INSTALL' "Database size: ${size}"
    local block_rows max_block
    block_rows=$(psql "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM block;" 2>/dev/null) || block_rows=
    if [[ "$block_rows" =~ ^[0-9]+$ ]]; then
        max_block=$(psql "$POSTGRES_DB" -tAc "SELECT MAX(block_no) FROM block;" 2>/dev/null) || max_block=
        print 'INSTALL' "block table rows: ${block_rows} (max block_no: ${max_block:-n/a})"
    fi
    return 0
}

dbsync_watch_import() {
    _require_warm_node || return 1
    print 'INSTALL' 'Polling import progress every 30s (Ctrl+C stops this watch only)'
    while true; do
        echo "--- $(date -u +%Y-%m-%dT%H:%M:%SZ) ---"
        dbsync_import_status
        sleep 30
    done
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
    export) dbsync_export_db ;;
    restore) dbsync_restore_db "${2:-}" ;;
    export-state) dbsync_export_state ;;
    import-state) dbsync_import_state ;;
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
    import-status) dbsync_import_status ;;
    watch-import) dbsync_watch_import ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
