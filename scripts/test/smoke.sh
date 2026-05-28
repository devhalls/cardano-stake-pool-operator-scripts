#!/bin/bash
# Smoke test suite — no live chain required.

run_suite_smoke() {
    run_test smoke_env_release test_smoke_env_release
    run_test smoke_env_template_drift test_smoke_env_template_drift
    run_test smoke_services_release test_smoke_services_release
    run_test smoke_config_source test_smoke_config_source
    run_test smoke_cardano_cli test_smoke_cardano_cli
    run_test smoke_help_address test_smoke_help_address
    run_test smoke_help_query test_smoke_help_query
    run_test smoke_help_pool test_smoke_help_pool
    run_test smoke_help_tx test_smoke_help_tx
    run_test smoke_help_govern test_smoke_help_govern
    run_test smoke_help_node test_smoke_help_node
    run_test smoke_help_dbsync test_smoke_help_dbsync
    run_test smoke_help_network test_smoke_help_network
    run_test smoke_help_midnight test_smoke_help_midnight
    run_test smoke_help_node_install test_smoke_help_node_install
    run_test smoke_install_validate test_smoke_install_validate
}

list_suite_smoke() {
    echo "smoke:"
    echo "  smoke_env_release"
    echo "  smoke_env_template_drift"
    echo "  smoke_services_release"
    echo "  smoke_config_source"
    echo "  smoke_cardano_cli"
    echo "  smoke_help_address"
    echo "  smoke_help_query"
    echo "  smoke_help_pool"
    echo "  smoke_help_tx"
    echo "  smoke_help_govern"
    echo "  smoke_help_node"
    echo "  smoke_help_dbsync"
    echo "  smoke_help_network"
    echo "  smoke_help_midnight"
    echo "  smoke_help_node_install"
    echo "  smoke_install_validate"
}

test_smoke_env_release() {
    env_validate_release
}

test_smoke_env_template_drift() {
    env_validate_template_drift
}

test_smoke_services_release() {
    services_validate_release
}

test_smoke_config_source() {
    # Repo layout (local / full checkout) or installed copy (docker after node.sh install)
    if [ -d "$CONFIG_SOURCE" ] && [ -f "$CONFIG_SOURCE/config.json" ]; then
        return 0
    fi
    if [ -f "$NETWORK_PATH/config.json" ]; then
        return 0
    fi
    echo "Config not found at $CONFIG_SOURCE (repo) or $NETWORK_PATH/config.json (installed)"
    return 1
}

test_smoke_cardano_cli() {
    if ! command -v "$CNCLI" >/dev/null 2>&1 && [ ! -x "$CNCLI" ]; then
        echo "cardano-cli not found at $CNCLI (skipped outside docker/install)"
        return 2
    fi
    capture_script node.sh version || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "node version returned no output" || return 1
    return 0
}

test_smoke_help_address() { assert_help address.sh; }
test_smoke_help_query() { assert_help query.sh; }
test_smoke_help_pool() { assert_help pool.sh; }
test_smoke_help_tx() { assert_help tx.sh; }
test_smoke_help_govern() { assert_help govern.sh; }
test_smoke_help_node() { assert_help node.sh; }
test_smoke_help_dbsync() { assert_help dbsync.sh; }
test_smoke_help_network() { assert_help network.sh; }
test_smoke_help_midnight() { assert_help midnight.sh; }

test_smoke_help_node_install() {
    local out
    local code=0
    out="$(bash "$TEST_SCRIPTS_DIR/node/install.sh" help 2>&1)" || code=$?
    if [ "$code" -ne 1 ]; then
        echo "help for node/install.sh expected exit 1, got $code"
        return 1
    fi
    echo "$out" | grep -q 'Usage:' || return 1
}

test_smoke_install_validate() {
    if [ -d "$NETWORK_PATH/keys" ]; then
        echo "keys directory already exists (installed environment)"
        return 2
    fi
    capture_script node/install.sh validate || return 1
    echo "$TEST_LAST_CAPTURE" | grep -qi 'passed' || return 1
    return 0
}
