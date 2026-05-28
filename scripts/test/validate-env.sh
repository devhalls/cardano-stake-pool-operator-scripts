#!/bin/bash
# Release-versioned env validation for smoke tests.

# Override with TEST_ENV_RELEASE or test.sh --release <version>
env_validate_release_id() {
    echo "${TEST_ENV_RELEASE:-$NODE_VERSION}"
}

env_validate_manifest_path() {
    local release="$1"
    local profile="${2:-}"
    local base="$TEST_SCRIPTS_DIR/test/releases/${release}.manifest"
    if [ -n "$profile" ] && [ -f "$TEST_SCRIPTS_DIR/test/releases/${release}.${profile}.manifest" ]; then
        echo "$TEST_SCRIPTS_DIR/test/releases/${release}.${profile}.manifest"
        return 0
    fi
    echo "$base"
}

env_validate_list_releases() {
    local f
    for f in "$TEST_SCRIPTS_DIR/test/releases/"*.manifest; do
        [ -f "$f" ] || continue
        basename "$f" .manifest | grep -vE '\.(docker|services|configs)$' || true
    done | sort -u
}

env_validate_manifest_var_names() {
    local manifest="$1"
    grep -E '^(REQUIRED|OPTIONAL|PIN) ' "$manifest" | awk '{print $2}' | sort -u
}

env_file_var_names() {
    local file="$1"
    [ -f "$file" ] || return 1
    grep -E '^[A-Z][A-Z0-9_]*=' "$file" | cut -d= -f1 | sort -u
}

env_file_get_value() {
    local file="$1"
    local name="$2"
    local line val

    line="$(grep -E "^${name}=" "$file" 2>/dev/null | head -1)" || return 1
    val="${line#*=}"
    val="${val%$'\r'}"
    val="${val#\"}"
    val="${val%\"}"
    val="${val#\'}"
    val="${val%\'}"
    echo "$val"
}

env_file_var_is_set() {
    local file="$1"
    local name="$2"
    grep -qE "^${name}=" "$file" 2>/dev/null
}

# Validate a single env file against one or more manifest paths (space-separated)
env_validate_file_manifests() {
    local file="$1"
    shift
    local manifest errors=0
    local line kind name expected actual
    local combined_vars file_vars k all_manifests

    if [ ! -f "$file" ]; then
        echo "missing env file: $file"
        return 1
    fi

    echo "file=$file"
    all_manifests="$*"
    combined_vars=""
    for manifest in "$@"; do
        if [ ! -f "$manifest" ]; then
            echo "missing manifest: $manifest"
            return 1
        fi
        combined_vars+="$(env_validate_manifest_var_names "$manifest")"$'\n'
    done
    combined_vars="$(echo "$combined_vars" | sort -u)"
    file_vars="$(env_file_var_names "$file")"

    while IFS= read -r k; do
        [ -z "$k" ] && continue
        if ! echo "$combined_vars" | grep -qx "$k"; then
            echo "extra key in file (not in manifest): $k"
            errors=$((errors + 1))
        fi
    done <<<"$file_vars"

    for manifest in "$@"; do
        echo "manifest=$manifest"

        while IFS= read -r k; do
            [ -z "$k" ] && continue
            if ! env_file_var_is_set "$file" "$k"; then
                echo "missing key in file: $k"
                errors=$((errors + 1))
            fi
        done < <(env_validate_manifest_var_names "$manifest")

        while IFS= read -r line || [ -n "$line" ]; do
            line="${line%%#*}"
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [ -z "$line" ] && continue

            kind="${line%% *}"
            name="${line#* }"
            expected=""

            case "$kind" in
                REQUIRED|OPTIONAL)
                    name="${name%% *}"
                    ;;
                PIN)
                    name="$(echo "$line" | awk '{print $2}')"
                    expected="$(echo "$line" | cut -d' ' -f3-)"
                    ;;
                *)
                    continue
                    ;;
            esac

            if ! env_file_var_is_set "$file" "$name"; then
                echo "unset in file: $name"
                errors=$((errors + 1))
                continue
            fi

            actual="$(env_file_get_value "$file" "$name")"

            case "$kind" in
                REQUIRED)
                    if [ -z "$actual" ]; then
                        echo "empty (required) in file: $name"
                        errors=$((errors + 1))
                    fi
                    ;;
                PIN)
                    if [ "$actual" != "$expected" ]; then
                        echo "pin mismatch in file: $name expected='$expected' actual='$actual'"
                        errors=$((errors + 1))
                    fi
                    ;;
            esac
        done <"$manifest"
    done

    [ "$errors" -eq 0 ]
}

# Returns 0 if var is set in shell (may be empty)
env_validate_var_is_set() {
    local name="$1"
    eval "[ -n \"\${${name}+x}\" ]"
}

env_validate_var_nonempty() {
    local name="$1"
    local value="${!name}"
    [ -n "$value" ]
}

env_validate_apply_manifest() {
    local manifest="$1"
    local errors=0
    local line kind name expected actual

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        kind="${line%% *}"
        name="${line#* }"
        expected=""

        case "$kind" in
            REQUIRED|OPTIONAL)
                name="${name%% *}"
                ;;
            PIN)
                name="$(echo "$line" | awk '{print $2}')"
                expected="$(echo "$line" | cut -d' ' -f3-)"
                ;;
            *)
                continue
                ;;
        esac

        if ! env_validate_var_is_set "$name"; then
            echo "unset (runtime): $name"
            errors=$((errors + 1))
            continue
        fi

        case "$kind" in
            REQUIRED)
                if ! env_validate_var_nonempty "$name"; then
                    echo "empty (required, runtime): $name"
                    errors=$((errors + 1))
                fi
                ;;
            PIN)
                actual="${!name}"
                if [ "$actual" != "$expected" ]; then
                    echo "pin mismatch (runtime): $name expected='$expected' actual='$actual'"
                    errors=$((errors + 1))
                fi
                ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

env_validate_common_derived() {
    local errors=0

    if [ -z "$CONFIG_SOURCE" ]; then
        echo "empty (derived): CONFIG_SOURCE"
        errors=$((errors + 1))
    fi

    case "$NODE_NETWORK" in
        mainnet | preprod | preview | sanchonet)
            if [ -z "$NETWORK_ARG" ]; then
                echo "empty (derived): NETWORK_ARG for NODE_NETWORK=$NODE_NETWORK"
                errors=$((errors + 1))
            fi
            ;;
        *)
            echo "unknown NODE_NETWORK: $NODE_NETWORK"
            errors=$((errors + 1))
            ;;
    esac

    case "$NODE_TYPE" in
        relay | producer)
            if [ -z "$CONFIG_PATH" ]; then
                echo "empty (derived): CONFIG_PATH for NODE_TYPE=$NODE_TYPE"
                errors=$((errors + 1))
            fi
            ;;
        cold) ;;
        *)
            echo "unknown NODE_TYPE: $NODE_TYPE"
            errors=$((errors + 1))
            ;;
    esac

    [ "$errors" -eq 0 ]
}

# Validate env.example, env.docker, and env on disk against release manifests
env_validate_env_files() {
    local release base docker total=0
    local env_example env_docker env_runtime

    release="$(env_validate_release_id)"
    base="$(env_validate_manifest_path "$release")"
    docker="$(env_validate_manifest_path "$release" docker)"

    if [ ! -f "$base" ]; then
        echo "no manifest for release $release"
        return 1
    fi

    echo "release=$release env_files_check"

    env_example="$REPO_ROOT/env.example"
    env_docker="$REPO_ROOT/env.docker"
    env_runtime="$REPO_ROOT/env"

    if [ -f "$env_example" ]; then
        if ! env_validate_file_manifests "$env_example" "$base"; then
            total=$((total + 1))
        fi
    elif [ "$TEST_IN_DOCKER" -eq 1 ]; then
        echo "skip env.example (not mounted in Docker)"
    else
        echo "missing env.example at $env_example"
        total=$((total + 1))
    fi

    if [ -f "$env_docker" ]; then
        if [ -f "$docker" ]; then
            if ! env_validate_file_manifests "$env_docker" "$base" "$docker"; then
                total=$((total + 1))
            fi
        else
            if ! env_validate_file_manifests "$env_docker" "$base"; then
                total=$((total + 1))
            fi
        fi
    else
        echo "missing env.docker at $env_docker"
        total=$((total + 1))
    fi

    if [ -f "$env_runtime" ]; then
        if [ "$TEST_IN_DOCKER" -eq 1 ] && [ -f "$docker" ] && [ -f "$env_docker" ]; then
            # env is copied from env.docker at container start — must match after env.docker changes
            local pin_name pin_expected pin_actual
            for pin_name in NODE_VERSION GHC_VERSION CABAL_VERSION MITHRIL_VERSION NODE_PORT NETWORK_SOCKET_PATH; do
                grep -qE "^PIN ${pin_name} " "$base" 2>/dev/null || grep -qE "^PIN ${pin_name} " "$docker" 2>/dev/null || continue
                pin_expected="$(env_file_get_value "$env_docker" "$pin_name")"
                pin_actual="$(env_file_get_value "$env_runtime" "$pin_name")"
                if [ "$pin_expected" != "$pin_actual" ]; then
                    echo "env out of date vs env.docker: $pin_name docker='$pin_expected' env='$pin_actual' (restart node container)"
                    total=$((total + 1))
                fi
            done
            if [ "$total" -eq 0 ]; then
                echo "env matches env.docker runtime pins"
            fi
        elif [ "$TEST_IN_DOCKER" -eq 1 ] && [ -f "$docker" ]; then
            if ! env_validate_file_manifests "$env_runtime" "$base" "$docker"; then
                total=$((total + 1))
            fi
        else
            if ! env_validate_file_manifests "$env_runtime" "$base"; then
                total=$((total + 1))
            fi
        fi
    elif [ "$TEST_IN_DOCKER" -eq 1 ]; then
        echo "missing env at $env_runtime (expected entrypoint copy from env.docker)"
        total=$((total + 1))
    else
        echo "missing env at $env_runtime (copy from env.example for local runs)"
        total=$((total + 1))
    fi

    [ "$total" -eq 0 ]
}

# Full validation for current shell env against release manifest(s)
env_validate_release() {
    local release profile manifest errors=0 total=0
    release="$(env_validate_release_id)"

    if [ ! -f "$TEST_SCRIPTS_DIR/test/releases/${release}.manifest" ]; then
        echo "no manifest for release $release (available: $(env_validate_list_releases | tr '\n' ' '))"
        return 1
    fi

    echo "release=$release runtime_env_check"
    if [ "$TEST_IN_DOCKER" -eq 1 ]; then
        echo "env_profile=docker"
    else
        echo "env_profile=local"
    fi

    manifest="$(env_validate_manifest_path "$release")"
    echo "manifest=$manifest"
    if ! env_validate_apply_manifest "$manifest"; then
        total=$((total + 1))
    fi

    if [ "$TEST_IN_DOCKER" -eq 1 ]; then
        profile="docker"
        manifest="$(env_validate_manifest_path "$release" "$profile")"
        if [ -f "$manifest" ]; then
            echo "profile=$profile manifest=$manifest"
            if ! env_validate_apply_manifest "$manifest"; then
                total=$((total + 1))
            fi
        fi
    fi

    echo "--- common.sh derived ---"
    if ! env_validate_common_derived; then
        total=$((total + 1))
    fi

    [ "$total" -eq 0 ]
}
