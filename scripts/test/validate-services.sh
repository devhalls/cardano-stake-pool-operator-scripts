#!/bin/bash
# Release-versioned systemd unit and db-sync schema validation.

SERVICES_VALIDATE_ROWS=()

services_validate_add_row() {
    local state="$1"
    local check="$2"
    local name="$3"
    local detail="$4"
    SERVICES_VALIDATE_ROWS+=("$(table_status_row "$state" "$check" "$name" "$detail")")
}

services_validate_print_rows() {
    [ ${#SERVICES_VALIDATE_ROWS[@]} -eq 0 ] && return 0
    print_table_titled "Service checks" "$(table_header CHECK NAME DETAIL)" "${SERVICES_VALIDATE_ROWS[@]}"
}

services_validate_release_id() {
    echo "${TEST_ENV_RELEASE:-$NODE_VERSION}"
}

services_validate_dir() {
    if [ -n "$SERVICES_SOURCE" ] && [ -d "$SERVICES_SOURCE" ]; then
        echo "$SERVICES_SOURCE"
    elif [ -d "$REPO_ROOT/configs/services" ]; then
        echo "$REPO_ROOT/configs/services"
    elif [ -d "$NODE_HOME/configs/services" ]; then
        echo "$NODE_HOME/configs/services"
    fi
}

services_validate_schema_dir() {
    if [ -n "$SCHEMA_SOURCE" ] && [ -d "$SCHEMA_SOURCE" ]; then
        echo "$SCHEMA_SOURCE"
    elif [ -d "$REPO_ROOT/configs/schema" ]; then
        echo "$REPO_ROOT/configs/schema"
    elif [ -d "$NODE_HOME/configs/schema" ]; then
        echo "$NODE_HOME/configs/schema"
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
            echo "missing placeholder: $var"
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
        services_validate_add_row "" "template" "-" "services directory not found"
        echo "services directory not found"
        return 1
    fi

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
                    services_validate_add_row "" "template" "$template" "missing template"
                    errors=$((errors + 1))
                    continue
                fi

                if ! services_validate_unit_format "$path"; then
                    services_validate_add_row "" "template" "$template" "invalid systemd unit format"
                    errors=$((errors + 1))
                    continue
                fi

                if [ -n "$subs" ]; then
                    local placeholder_ok=1
                    for var in $subs; do
                        local placeholder_msg
                        if ! placeholder_msg="$(services_validate_template_placeholders "$path" "$var")"; then
                            services_validate_add_row "" "template" "$template" "$placeholder_msg"
                            errors=$((errors + 1))
                            placeholder_ok=0
                        fi
                    done
                    [ "$placeholder_ok" -eq 0 ] && continue
                fi
                services_validate_add_row "ok" "template" "$template" "ok"
                ;;
            PACKAGED|SCHEMA_PIN|SCHEMA_HEAD) ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

services_validate_deploy_manifest() {
    local manifest="$1"
    local services_dir schema_dir errors=0
    local line kind env_var template subs optional rendered path

    services_dir="$(services_validate_dir)"
    schema_dir="$(services_validate_schema_dir)"
    if [ -z "$services_dir" ] || [ ! -d "$services_dir" ]; then
        services_validate_add_row "" "deploy" "-" "services directory not found"
        echo "services directory not found"
        return 1
    fi

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
                    services_validate_add_row "" "deploy" "$template" "missing template for $env_var"
                    errors=$((errors + 1))
                    continue
                fi

                if [ "$kind" = "SERVICE" ] || [ "$kind" = "OPTIONAL_SERVICE" ]; then
                    if ! env_validate_var_nonempty "$env_var"; then
                        services_validate_add_row "" "deploy" "$env_var" "empty service env"
                        errors=$((errors + 1))
                        continue
                    fi
                fi

                if [ -n "$subs" ]; then
                    # shellcheck disable=SC2086
                    rendered="$(services_validate_render_unit "$template" $subs)" || {
                        services_validate_add_row "" "deploy" "$template" "failed to render"
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
                        local minus plus detail
                        minus="$(diff -u "$rendered" "$path" | grep '^-[^-]' | head -1 | sed 's/^-[[:space:]]*//')"
                        plus="$(diff -u "$rendered" "$path" | grep '^+[^+]' | head -1 | sed 's/^+[[:space:]]*//')"
                        detail="out of date at $path (re-run install for $env_var)"
                        if [ -n "$minus" ] && [ -n "$plus" ]; then
                            detail="${detail}: ${minus} -> ${plus}"
                        fi
                        services_validate_add_row "" "deploy" "$(basename "$path")" "$detail"
                        errors=$((errors + 1))
                    else
                        services_validate_add_row "ok" "deploy" "$(basename "$path")" "current"
                    fi
                elif [ "$optional" -eq 1 ]; then
                    services_validate_add_row "skip" "deploy" "$env_var" "optional component not installed ($template)"
                else
                    services_validate_add_row "skip" "deploy" "$(basename "$path")" "unit not installed at $path"
                fi
                rm -f "$rendered"
                ;;

            PACKAGED)
                env_var="${line%% *}"
                template="${line#* }"
                if ! env_validate_var_nonempty "$env_var"; then
                    services_validate_add_row "" "packaged" "$env_var" "empty packaged service env"
                    errors=$((errors + 1))
                    continue
                fi
                if [ "${!env_var}" != "$template" ]; then
                    services_validate_add_row "" "packaged" "$env_var" "name mismatch expected='$template' actual='${!env_var}'"
                    errors=$((errors + 1))
                fi
                local packaged_found=0
                for path in "$SERVICE_PATH/$template" "/lib/systemd/system/$template" "/etc/systemd/system/$template"; do
                    if [ -f "$path" ]; then
                        services_validate_add_row "ok" "packaged" "$template" "present at $path"
                        packaged_found=1
                        break
                    fi
                done
                if [ "$packaged_found" -eq 0 ]; then
                    services_validate_add_row "skip" "packaged" "$template" "unit file not found on disk"
                fi
                ;;

            SCHEMA_PIN | SCHEMA_HEAD)
                # Rows come from services_validate_schema_manifest; keep checks for return code only.
                if ! services_validate_dbsync_installed; then
                    continue
                fi
                if [ "$kind" = "SCHEMA_PIN" ]; then
                    env_var="${line%% *}"
                    local expected="${line#* }"
                    local actual="${!env_var}"
                    if [ "$actual" != "$expected" ]; then
                        errors=$((errors + 1))
                    fi
                else
                    local head_file="$line"
                    if [ -z "$schema_dir" ] || [ ! -f "$schema_dir/$head_file" ]; then
                        errors=$((errors + 1))
                    fi
                fi
                ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

services_validate_schema_manifest() {
    local manifest="$1"
    local schema_dir errors=0
    local line kind env_var expected head_file count

    schema_dir="$(services_validate_schema_dir)"
    if [ ! -d "$schema_dir" ]; then
        services_validate_add_row "" "schema" "-" "schema directory not found"
        return 1
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue
        kind="${line%% *}"
        line="${line#* }"

        case "$kind" in
            SCHEMA_PIN)
                if ! services_validate_dbsync_installed; then
                    services_validate_add_row "skip" "schema" "${line%% *}" "db-sync not installed, skipping pin"
                    continue
                fi
                env_var="${line%% *}"
                expected="${line#* }"
                if [ "${!env_var}" != "$expected" ]; then
                    services_validate_add_row "" "schema" "$env_var" "pin mismatch expected='$expected' actual='${!env_var}'"
                    errors=$((errors + 1))
                else
                    services_validate_add_row "ok" "schema" "$env_var" "pin $expected"
                fi
                ;;
            SCHEMA_HEAD)
                if ! services_validate_dbsync_installed; then
                    services_validate_add_row "skip" "schema" "$line" "db-sync not installed, skipping head"
                    continue
                fi
                head_file="$line"
                if [ ! -f "$schema_dir/$head_file" ]; then
                    services_validate_add_row "" "schema" "$head_file" "head missing at $schema_dir/$head_file"
                    errors=$((errors + 1))
                fi
                count="$(find "$schema_dir" -maxdepth 1 -name 'migration-*.sql' 2>/dev/null | wc -l | tr -d ' ')"
                services_validate_add_row "ok" "schema" "$head_file" "$count migrations"
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

    SERVICES_VALIDATE_ROWS=()
    local profile="local"
    [ "$TEST_IN_DOCKER" -eq 1 ] && profile="docker"

    print_table_titled "Services" \
        "KEY | VALUE" \
        "release | $release" \
        "manifest | $manifest" \
        "profile | $profile" \
        "services_dir | $(services_validate_dir)"

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
        services_validate_add_row "skip" "deploy" "-" "systemd deploy diff skipped (docker or non-systemd host)"
    fi

    services_validate_print_rows
    if [ "$total" -gt 0 ]; then
        echo "$total service check group(s) failed"
    fi
    [ "$total" -eq 0 ]
}
