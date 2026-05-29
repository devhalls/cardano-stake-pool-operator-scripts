#!/bin/bash
# Release-versioned cardano-node config bundle validation.

configs_validate_release_id() {
    echo "${TEST_ENV_RELEASE:-$NODE_VERSION}"
}

configs_validate_manifest_path() {
    local release="$1"
    echo "$TEST_SCRIPTS_DIR/test/releases/${release}.configs.manifest"
}

configs_validate_list_releases() {
    local f
    for f in "$TEST_SCRIPTS_DIR/test/releases/"*.configs.manifest; do
        [ -f "$f" ] || continue
        basename "$f" .configs.manifest
    done | sort -u
}

configs_validate_bundle_root() {
    local release="$1"
    if [ -d "$REPO_ROOT/configs/node/$release" ]; then
        echo "$REPO_ROOT/configs/node/$release"
        return 0
    fi
    if [ -d "$NODE_HOME/configs/node/$release" ]; then
        echo "$NODE_HOME/configs/node/$release"
        return 0
    fi
    return 1
}

configs_validate_json_file() {
    local path="$1"
    if command -v jq >/dev/null 2>&1; then
        if ! jq -e . "$path" >/dev/null 2>&1; then
            echo "invalid JSON: $path"
            return 1
        fi
        return 0
    fi
    if command -v python3 >/dev/null 2>&1; then
        if ! python3 -m json.tool "$path" >/dev/null 2>&1; then
            echo "invalid JSON: $path"
            return 1
        fi
        return 0
    fi
    echo "warn: no jq/python3 — skipping JSON syntax check for $path"
    return 0
}

configs_validate_apply_manifest() {
    local manifest="$1"
    local release bundle_root errors=0 total=0
    local line kind network rel_path full

    release="$(configs_validate_release_id)"
    bundle_root="$(configs_validate_bundle_root "$release")" || {
        echo "config bundle not found for release $release under configs/node/"
        return 1
    }

    echo "configs_root=$bundle_root"
    network=""

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%#*}"
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$line" ] && continue

        kind="${line%% *}"
        line="${line#* }"

        case "$kind" in
            NETWORK)
                network="$line"
                echo "--- network=$network ---"
                ;;
            FILE)
                if [ -z "$network" ]; then
                    echo "FILE line before NETWORK: $line"
                    errors=$((errors + 1))
                    continue
                fi
                rel_path="$line"
                full="$bundle_root/$network/$rel_path"
                if [ ! -f "$full" ]; then
                    echo "missing: $network/$rel_path"
                    errors=$((errors + 1))
                    continue
                fi
                case "$rel_path" in
                    peer-snapshot.json)
                        if ! configs_validate_json_file "$full"; then
                            errors=$((errors + 1))
                        elif ! jq -e '.NetworkMagic and .Point.blockPointSlot and .Point.blockPointHash and (.bigLedgerPools | type == "array" and length > 0)' "$full" >/dev/null 2>&1; then
                            echo "peer-snapshot must use LedgerBigPeerSnapshotV23 (NetworkMagic, Point, bigLedgerPools): $network/$rel_path"
                            errors=$((errors + 1))
                        elif jq -e '.version or .slotNo or .bigLedgerPeers' "$full" >/dev/null 2>&1; then
                            echo "peer-snapshot must not use legacy version/slotNo/bigLedgerPeers format: $network/$rel_path"
                            errors=$((errors + 1))
                        else
                            echo "ok: $network/$rel_path"
                        fi
                        ;;
                    topology-relay.json|topology-producer.json)
                        echo "ok: $network/$rel_path (rendered on sync)"
                        ;;
                    config.json|config-bp.json)
                        if ! configs_validate_json_file "$full"; then
                            errors=$((errors + 1))
                        elif ! command -v jq >/dev/null 2>&1; then
                            echo "ok: $network/$rel_path"
                        elif ! jq -e '.UseTraceDispatcher == true' "$full" >/dev/null 2>&1; then
                            echo "UseTraceDispatcher must be true: $network/$rel_path"
                            errors=$((errors + 1))
                        elif [ "$(jq -r '.TraceOptions.Mempool.severity // empty' "$full")" != "Info" ]; then
                            echo "TraceOptions.Mempool.severity must be Info (txsProcessedNum metrics): $network/$rel_path"
                            errors=$((errors + 1))
                        else
                            echo "ok: $network/$rel_path"
                        fi
                        ;;
                    *.json)
                        if ! configs_validate_json_file "$full"; then
                            errors=$((errors + 1))
                        else
                            echo "ok: $network/$rel_path"
                        fi
                        ;;
                    *)
                        echo "ok: $network/$rel_path"
                        ;;
                esac
                ;;
            *)
                echo "unknown manifest line: $kind $line"
                errors=$((errors + 1))
                ;;
        esac
    done <"$manifest"

    [ "$errors" -eq 0 ]
}

configs_validate_release() {
    local release manifest

    release="$(configs_validate_release_id)"
    manifest="$(configs_validate_manifest_path "$release")"

    if [ ! -f "$manifest" ]; then
        echo "no configs manifest for release $release (available: $(configs_validate_list_releases | tr '\n' ' '))"
        return 1
    fi

    echo "release=$release"
    echo "manifest=$manifest"

    configs_validate_apply_manifest "$manifest"
}
