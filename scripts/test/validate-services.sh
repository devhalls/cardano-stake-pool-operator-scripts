#!/bin/bash
# Release-versioned systemd unit and db-sync schema validation.

services_validate_release_id() {
    echo "${TEST_ENV_RELEASE:-$NODE_VERSION}"
}

services_validate_dir() {
    if [ -d "$REPO_ROOT/services" ]; then
        echo "$REPO_ROOT/services"
    elif [ -d "$NODE_HOME/services" ]; then
        echo "$NODE_HOME/services"
    fi
}

services_validate_manifest_path() {
    local release="$1"
    echo "$TEST_SCRIPTS_DIR/test/releases/${release}.services.manifest"
}

services_validate_list_releases() {
    local f
    for f in "$TEST_SCRIPTS_DIR/test/releases/"*.services.manifest; do
        [ -f "$f" ] || continue
        basename "$f" .services.manifest
    done | sort -u
}

services_validate_dbsync_installed() {
    if [ -n "$DB_SYNC" ] && [ -x "$DB_SYNC" ]; then
        return 0
    fi
    if [ -d "$DB_SYNC_PATH/schema" ] && find "$DB_SYNC_PATH/schema" -maxdepth 1 -name 'migration-*.sql' 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

services_validate_sed_inplace() {
    local file="$1"
    local var value
    shift
    for var in "$@"; do
        value="${!var}"
        if sed --version 2>/dev/null | grep -q GNU; then
            sed -i "s|${var}|${value}|g" "$file"
        else
            sed -i '' "s|${var}|${value}|g" "$file"
        fi
    done
}

services_validate_render_unit() {
    local template="$1"
    shift
    local services_dir rendered
    services_dir="$(services_validate_dir)"
    rendered="$(mktemp)"
    cp "$services_dir/$template" "$rendered" || return 1
    if [ $# -gt 0 ]; then
        services_validate_sed_inplace "$rendered" "$@"
    fi
    echo "$rendered"
}

services_validate_deployed_path() {
    local env_var="$1"
    local template="$2"
    local name="${!env_var}"

    case "$template" in
        squid.service) echo "/etc/systemd/system/$name" ;;
        *) echo "$SERVICE_PATH/$name" ;;
    esac
}

services_validate_unit_format() {
    local file="$1"
    grep -q '^\[Unit\]' "$file" || return 1
    grep -q '^\[Service\]' "$file" || return 1
    grep -q '^\[Install\]' "$file" || return 1
    return 0
}

services_validate_template_placeholders() {
    local template="$1"
    shift
    local var
    for var in "$@"; do
        if ! grep -q "$var" "$template"; then
            echo "template missing placeholder: $var in $(basename "$template")"
            return 1
        fi
    done
    return 0
}

# Templates listed in manifest must exist and match expected systemd layout
services_validate_templates_manifest() {
    local manifest="$1"
    local services_dir errors=0
    local line kind env_var template subs optional path var

    services_dir="$(services_validate_dir)"
    if [ -z "$services_dir" ] || [ ! -d "$services_dir" ]; then
        echo "services directory not found"
        return 1
    fi

    echo "services_dir=$services_dir templates_check"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        kind="${line%% *}"
        line="${line#* }"

        case "$kind" in
            SERVICE|OPTIONAL_SERVICE|UNIT_STATIC|OPTIONAL_UNIT_STATIC)
                env_var="${line%% *}"
                line="${line#* }"
                template="${line%% *}"
                if [ "$kind" = "UNIT_STATIC" ] || [ "$kind" = "OPTIONAL_UNIT_STATIC" ]; then
                    subs=""
                else
                    subs="${line#* }"
                fi

                path="$services_dir/$template"
                if [ ! -f "$path" ]; then
                    echo "missing template: $template"
                    errors=$((errors + 1))
                    continue
                fi

                if ! services_validate_unit_format "$path"; then
                    echo "invalid systemd unit format: $template"
                    errors=$((errors + 1))
                fi

                if [ -n "$subs" ]; then
                    for var in $subs; do
                        if ! services_validate_template_placeholders "$path" "$var"; then
                            errors=$((errors + 1))
                        fi
                    done
                fi
                echo "template ok: $template"
                ;;
            PACKAGED|SCHEMA_PIN|SCHEMA_HEAD) ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

services_validate_deploy_manifest() {
    local manifest="$1"
    local services_dir errors=0
    local line kind env_var template subs optional rendered path

    services_dir="$(services_validate_dir)"
    if [ -z "$services_dir" ] || [ ! -d "$services_dir" ]; then
        echo "services directory not found"
        return 1
    fi

    echo "services_dir=$services_dir deploy_check"

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        kind="${line%% *}"
        line="${line#* }"
        optional=0

        case "$kind" in
            SERVICE|OPTIONAL_SERVICE|UNIT_STATIC|OPTIONAL_UNIT_STATIC)
                case "$kind" in
                    OPTIONAL_SERVICE|OPTIONAL_UNIT_STATIC) optional=1 ;;
                esac
                env_var="${line%% *}"
                line="${line#* }"
                template="${line%% *}"
                if [ "$kind" = "UNIT_STATIC" ] || [ "$kind" = "OPTIONAL_UNIT_STATIC" ]; then
                    subs=""
                else
                    subs="${line#* }"
                fi

                if [ ! -f "$services_dir/$template" ]; then
                    echo "missing template: $template (for $env_var)"
                    errors=$((errors + 1))
                    continue
                fi

                if [ "$kind" = "SERVICE" ] || [ "$kind" = "OPTIONAL_SERVICE" ]; then
                    if ! env_validate_var_nonempty "$env_var"; then
                        echo "empty service env: $env_var"
                        errors=$((errors + 1))
                        continue
                    fi
                fi

                if [ -n "$subs" ]; then
                    # shellcheck disable=SC2086
                    rendered="$(services_validate_render_unit "$template" $subs)" || {
                        echo "failed to render: $template"
                        errors=$((errors + 1))
                        continue
                    }
                else
                    rendered="$(mktemp)"
                    cp "$services_dir/$template" "$rendered"
                fi

                path="$(services_validate_deployed_path "$env_var" "$template")"
                if [ -f "$path" ]; then
                    if ! diff -q "$rendered" "$path" >/dev/null 2>&1; then
                        echo "deployed unit out of date: $path (re-run install for $env_var)"
                        diff -u "$rendered" "$path" | sed 's/^/  /' || true
                        errors=$((errors + 1))
                    else
                        echo "deployed unit current: $path"
                    fi
                elif [ "$optional" -eq 1 ]; then
                    echo "optional component not installed: $env_var ($template)"
                else
                    echo "deployed unit not installed: $path"
                fi
                rm -f "$rendered"
                ;;

            PACKAGED)
                env_var="${line%% *}"
                template="${line#* }"
                if ! env_validate_var_nonempty "$env_var"; then
                    echo "empty packaged service env: $env_var"
                    errors=$((errors + 1))
                    continue
                fi
                if [ "${!env_var}" != "$template" ]; then
                    echo "packaged service name mismatch: $env_var expected='$template' actual='${!env_var}'"
                    errors=$((errors + 1))
                fi
                for path in "$SERVICE_PATH/$template" "/lib/systemd/system/$template" "/etc/systemd/system/$template"; do
                    if [ -f "$path" ]; then
                        echo "packaged unit present: $path"
                        break
                    fi
                done
                ;;

            SCHEMA_PIN)
                if ! services_validate_dbsync_installed; then
                    echo "db-sync not installed, skipping schema pin"
                    continue
                fi
                env_var="${line%% *}"
                local expected="${line#* }"
                local actual="${!env_var}"
                if [ "$actual" != "$expected" ]; then
                    echo "schema pin mismatch: $env_var expected='$expected' actual='$actual'"
                    errors=$((errors + 1))
                fi
                ;;

            SCHEMA_HEAD)
                if ! services_validate_dbsync_installed; then
                    echo "db-sync not installed, skipping schema head"
                    continue
                fi
                local head_file="$line"
                if [ ! -f "$services_dir/schema/$head_file" ]; then
                    echo "schema head missing: $services_dir/schema/$head_file"
                    errors=$((errors + 1))
                fi
                local count
                count="$(find "$services_dir/schema" -maxdepth 1 -name 'migration-*.sql' 2>/dev/null | wc -l | tr -d ' ')"
                echo "schema migrations: $count files (head=$head_file)"
                ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

services_validate_schema_manifest() {
    local manifest="$1"
    local services_dir errors=0
    local line kind env_var expected head_file count

    services_dir="$(services_validate_dir)"
    [ -d "$services_dir" ] || return 1

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue
        kind="${line%% *}"
        line="${line#* }"

        case "$kind" in
            SCHEMA_PIN)
                if ! services_validate_dbsync_installed; then
                    echo "db-sync not installed, skipping schema pin"
                    continue
                fi
                env_var="${line%% *}"
                expected="${line#* }"
                if [ "${!env_var}" != "$expected" ]; then
                    echo "schema pin mismatch: $env_var expected='$expected' actual='${!env_var}'"
                    errors=$((errors + 1))
                fi
                ;;
            SCHEMA_HEAD)
                if ! services_validate_dbsync_installed; then
                    echo "db-sync not installed, skipping schema head"
                    continue
                fi
                head_file="$line"
                if [ ! -f "$services_dir/schema/$head_file" ]; then
                    echo "schema head missing: $services_dir/schema/$head_file"
                    errors=$((errors + 1))
                fi
                count="$(find "$services_dir/schema" -maxdepth 1 -name 'migration-*.sql' 2>/dev/null | wc -l | tr -d ' ')"
                echo "schema migrations: $count files (head=$head_file)"
                ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

services_validate_release() {
    local release manifest total=0

    release="$(services_validate_release_id)"
    manifest="$(services_validate_manifest_path "$release")"

    if [ ! -f "$manifest" ]; then
        echo "no services manifest for release $release (available: $(services_validate_list_releases | tr '\n' ' '))"
        return 1
    fi

    echo "release=$release"
    echo "manifest=$manifest"
    if [ "$TEST_IN_DOCKER" -eq 1 ]; then
        echo "services_profile=docker"
    else
        echo "services_profile=local"
    fi

    if ! services_validate_templates_manifest "$manifest"; then
        total=$((total + 1))
    fi

    if ! services_validate_schema_manifest "$manifest"; then
        total=$((total + 1))
    fi

    if platform_ctl 2>/dev/null; then
        if ! services_validate_deploy_manifest "$manifest"; then
            total=$((total + 1))
        fi
    else
        echo "systemd deploy diff skipped (docker or non-systemd host)"
    fi

    [ "$total" -eq 0 ]
}
