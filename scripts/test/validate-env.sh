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
        basename "$f" .manifest | grep -v '\.docker$' || true
    done | sort -u
}

# Canonical env template: env.docker in container, env.example in full repo checkout
env_validate_template_file() {
    if [ "$TEST_IN_DOCKER" -eq 1 ] && [ -f "$REPO_ROOT/env.docker" ]; then
        echo "$REPO_ROOT/env.docker"
    elif [ -f "$REPO_ROOT/env.example" ]; then
        echo "$REPO_ROOT/env.example"
    elif [ -f "$REPO_ROOT/env.docker" ]; then
        echo "$REPO_ROOT/env.docker"
    fi
}

env_template_var_names() {
    local template
    template="$(env_validate_template_file)"
    if [ -z "$template" ] || [ ! -f "$template" ]; then
        echo "env template missing (expected \$REPO_ROOT/env.docker or env.example)" >&2
        return 1
    fi
    grep -E '^[A-Z][A-Z0-9_]*=' "$template" | cut -d= -f1 | sort
}

env_validate_manifest_var_names() {
    local manifest="$1"
    grep -E '^(REQUIRED|OPTIONAL|PIN) ' "$manifest" | awk '{print $2}' | sort -u
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
            echo "unset: $name"
            errors=$((errors + 1))
            continue
        fi

        case "$kind" in
            REQUIRED)
                if ! env_validate_var_nonempty "$name"; then
                    echo "empty (required): $name"
                    errors=$((errors + 1))
                fi
                ;;
            PIN)
                actual="${!name}"
                if [ "$actual" != "$expected" ]; then
                    echo "pin mismatch: $name expected='$expected' actual='$actual'"
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

env_validate_template_manifest_sync() {
    local manifest="$1"
    local template errors=0 k

    template="$(env_validate_template_file)"
    if [ -z "$template" ] || [ ! -f "$template" ]; then
        echo "env template missing (expected \$REPO_ROOT/env.docker or env.example)"
        return 1
    fi

    echo "template=$template"

    while IFS= read -r k; do
        [ -z "$k" ] && continue
        if ! grep -qE "^(REQUIRED|OPTIONAL|PIN) ${k}( |$)" "$manifest"; then
            echo "template key missing from manifest: $k"
            errors=$((errors + 1))
        fi
    done < <(env_template_var_names)

    while IFS= read -r k; do
        [ -z "$k" ] && continue
        if ! grep -qE "^${k}=" "$template"; then
            echo "manifest entry not in template: $k"
            errors=$((errors + 1))
        fi
    done < <(env_validate_manifest_var_names "$manifest")

    [ "$errors" -eq 0 ]
}

# Full validation for current shell env against release manifest(s)
env_validate_release() {
    local release profile manifest errors=0 total=0
    release="$(env_validate_release_id)"

    if [ ! -f "$TEST_SCRIPTS_DIR/test/releases/${release}.manifest" ]; then
        echo "no manifest for release $release (available: $(env_validate_list_releases | tr '\n' ' '))"
        return 1
    fi

    echo "release=$release"
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

env_validate_template_drift() {
    local release manifest
    release="$(env_validate_release_id)"
    manifest="$TEST_SCRIPTS_DIR/test/releases/${release}.manifest"
    env_validate_template_manifest_sync "$manifest"
}
