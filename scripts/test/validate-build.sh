#!/bin/bash
# Release-versioned node build/download script validation.

build_validate_release_id() {
    echo "${TEST_ENV_RELEASE:-$NODE_VERSION}"
}

build_validate_manifest_path() {
    local release="$1"
    echo "$TEST_SCRIPTS_DIR/test/releases/${release}.build.manifest"
}

build_validate_manifest_pin() {
    local manifest="$1"
    local name="$2"
    local expected actual
    expected="$(grep -E "^PIN ${name} " "$manifest" | awk '{print $3}')"
    if [ -z "$expected" ]; then
        echo "manifest missing PIN: $name"
        return 1
    fi
    actual="${!name}"
    if [ "$actual" != "$expected" ]; then
        echo "pin mismatch: $name expected='$expected' actual='$actual'"
        return 1
    fi
    return 0
}

build_validate_scripts_present() {
    local manifest="$1"
    local line kind script path errors=0

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue
        kind="${line%% *}"
        [ "$kind" = "SCRIPT" ] || continue
        script="${line#* }"
        path="$TEST_SCRIPTS_DIR/$script"
        if [ ! -f "$path" ]; then
            echo "missing build script: $script"
            errors=$((errors + 1))
            continue
        fi
        if ! grep -q 'Usage:' "$path"; then
            echo "missing Usage block: $script"
            errors=$((errors + 1))
        fi
        echo "script ok: $script"
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

build_validate_script_contract() {
    local build_sh="$TEST_SCRIPTS_DIR/node/build.sh"
    local errors=0

    if grep -q 'input-output-hk/iohk-nix/master' "$build_sh"; then
        echo "build.sh must not resolve BLST from iohk-nix master (use cardano-node tag flake.lock)"
        errors=$((errors + 1))
    fi

    if ! grep -q 'cardano_build_lib_versions_from_node' "$build_sh"; then
        echo "build.sh must use cardano_build_lib_versions_from_node from common.sh"
        errors=$((errors + 1))
    fi

    if ! grep -q 'ghcup install ghc \$GHC_VERSION' "$build_sh"; then
        echo "build.sh must install ghc from \$GHC_VERSION"
        errors=$((errors + 1))
    fi

    if ! grep -q 'git checkout tags/\$NODE_VERSION' "$build_sh"; then
        echo "build.sh must checkout cardano-node tag \$NODE_VERSION"
        errors=$((errors + 1))
    fi

    if ! grep -q 'liburing' "$build_sh"; then
        echo "build.sh should install liburing (required for cardano-node 10.7+)"
        errors=$((errors + 1))
    fi

    if ! grep -q 'cardano_node_release_filenames' "$TEST_SCRIPTS_DIR/node/download.sh"; then
        echo "download.sh must use cardano_node_release_filenames (via common.sh)"
        errors=$((errors + 1))
    fi

    [ "$errors" -eq 0 ]
}

build_validate_download_release_pattern() {
    local manifest="$1"
    local version expected_prefix
    version="$(build_validate_release_id)"
    expected_prefix="$(grep '^PIN NODE_REMOTE_PREFIX ' "$manifest" | awk '{print $3}')"
    if [ -z "$expected_prefix" ]; then
        echo "manifest missing PIN NODE_REMOTE_PREFIX"
        return 1
    fi
    if [[ "$NODE_REMOTE" != "${expected_prefix}${version}"* ]]; then
        echo "NODE_REMOTE should start with ${expected_prefix}${version} (got: $NODE_REMOTE)"
        return 1
    fi
    local names
    names="$(cardano_node_release_filenames)" || return 1
    if ! echo "$names" | grep -q "cardano-node-${version}-"; then
        echo "cardano_node_release_filenames missing archive for version $version"
        return 1
    fi
    echo "download pattern ok for NODE_VERSION=$version"
    return 0
}

build_validate_resolved_lib_versions() {
    local manifest="$1"
    local release errors=0
    local resolved_iohk resolved_sodium resolved_secp resolved_blst
    local pin_iohk pin_sodium pin_secp pin_blst

    release="$(build_validate_release_id)"

    if ! cardano_build_lib_versions_from_node "$release"; then
        echo "could not resolve lib versions from cardano-node $release flake.lock (network?)"
        return 1
    fi

    resolved_iohk="$IOHKNIX_VERSION"
    resolved_sodium="$SODIUM_VERSION"
    resolved_secp="$SECP256K1_VERSION"
    resolved_blst="$BLST_VERSION"

    pin_iohk="$(grep '^PIN IOHKNIX_VERSION ' "$manifest" | awk '{print $3}')"
    pin_sodium="$(grep '^PIN SODIUM_VERSION ' "$manifest" | awk '{print $3}')"
    pin_secp="$(grep '^PIN SECP256K1_VERSION ' "$manifest" | awk '{print $3}')"
    pin_blst="$(grep '^PIN BLST_VERSION ' "$manifest" | awk '{print $3}')"

    echo "resolved IOHKNIX_VERSION=$resolved_iohk"
    echo "resolved SODIUM_VERSION=$resolved_sodium"
    echo "resolved SECP256K1_VERSION=$resolved_secp"
    echo "resolved BLST_VERSION=$resolved_blst"

    if [ "$resolved_iohk" != "$pin_iohk" ]; then
        echo "IOHKNIX_VERSION pin mismatch: manifest=$pin_iohk resolved=$resolved_iohk"
        errors=$((errors + 1))
    fi
    if [ "$resolved_sodium" != "$pin_sodium" ]; then
        echo "SODIUM_VERSION pin mismatch: manifest=$pin_sodium resolved=$resolved_sodium"
        errors=$((errors + 1))
    fi
    if [ "$resolved_secp" != "$pin_secp" ]; then
        echo "SECP256K1_VERSION pin mismatch: manifest=$pin_secp resolved=$resolved_secp"
        errors=$((errors + 1))
    fi
    if [ "$resolved_blst" != "$pin_blst" ]; then
        echo "BLST_VERSION pin mismatch: manifest=$pin_blst resolved=$resolved_blst"
        errors=$((errors + 1))
    fi

    [ "$errors" -eq 0 ]
}

build_validate_release() {
    local release manifest total=0

    release="$(build_validate_release_id)"
    manifest="$(build_validate_manifest_path "$release")"

    if [ ! -f "$manifest" ]; then
        echo "no build manifest for release $release"
        return 1
    fi

    echo "release=$release"
    echo "manifest=$manifest"

    echo "--- env compiler pins ---"
    if ! build_validate_manifest_pin "$manifest" NODE_VERSION; then
        total=$((total + 1))
    fi
    if ! build_validate_manifest_pin "$manifest" GHC_VERSION; then
        total=$((total + 1))
    fi
    if ! build_validate_manifest_pin "$manifest" CABAL_VERSION; then
        total=$((total + 1))
    fi

    echo "--- scripts ---"
    if ! build_validate_scripts_present "$manifest"; then
        total=$((total + 1))
    fi
    if ! build_validate_script_contract; then
        total=$((total + 1))
    fi

    echo "--- download ---"
    if ! build_validate_download_release_pattern "$manifest"; then
        total=$((total + 1))
    fi

    echo "--- upstream lib versions (flake.lock) ---"
    if ! build_validate_resolved_lib_versions "$manifest"; then
        total=$((total + 1))
    fi

    [ "$total" -eq 0 ]
}
