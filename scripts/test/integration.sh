#!/bin/bash
# Integration tests — require a running node and socket.

run_suite_integration() {
    if ! require_socket; then
        skip_test integration_suite "node socket not available at $NETWORK_SOCKET_PATH"
        return 0
    fi

    # tip / chain
    run_test integration_query_tip_slot test_integration_query_tip_slot
    run_test integration_query_tip_epoch test_integration_query_tip_epoch
    run_test integration_query_tip_block test_integration_query_tip_block
    run_test integration_query_tip_hash test_integration_query_tip_hash

    # protocol parameters
    run_test integration_query_params_min_pool_cost test_integration_query_params_min_pool_cost
    run_test integration_query_params_stake_deposit test_integration_query_params_stake_deposit
    run_test integration_query_params_writes_json test_integration_query_params_writes_json

    # node metrics / version
    run_test integration_query_metrics test_integration_query_metrics
    run_test integration_query_metrics_cardano_series test_integration_query_metrics_cardano_series
    run_test integration_node_version test_integration_node_version

    # local config / kes period (no pool keys required)
    run_test integration_query_config_json test_integration_query_config_json
    run_test integration_query_kes_period test_integration_query_kes_period

    # wallet / stake (skip when keys absent — create via docker/fixture.sh)
    run_test integration_query_uxto test_integration_query_uxto
    run_test integration_query_rewards test_integration_query_rewards
    run_test integration_query_key_payment_addr test_integration_query_key_payment_addr

    # producer-only queries
    run_test integration_query_kes test_integration_query_kes
    run_test integration_query_leader_next test_integration_query_leader_next
}

list_suite_integration() {
    echo "integration (requires socket):"
    echo "  chain: integration_query_tip_slot|epoch|block|hash"
    echo "  params: integration_query_params_min_pool_cost|stake_deposit|writes_json"
    echo "  metrics: integration_query_metrics|metrics_cardano_series"
    echo "  integration_node_version"
    echo "  config: integration_query_config_json"
    echo "  integration_query_kes_period"
    echo "  wallet (optional keys): integration_query_uxto|rewards|key_payment_addr"
    echo "  producer (optional): integration_query_kes|leader_next"
}

# --- helpers ---

_integration_query() {
    capture_script query.sh "$@" || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "${1:-query} returned no output" || return 1
}

_integration_query_numeric() {
    local field="$1"
    shift
    _integration_query "$@" || return 1
    assert_matches "$TEST_LAST_CAPTURE" '^[0-9]+$' "$field should be numeric" || return 1
}

# --- tip ---

test_integration_query_tip_slot() {
    _integration_query_numeric "tip slot" tip slot
}

test_integration_query_tip_epoch() {
    _integration_query_numeric "tip epoch" tip epoch
}

test_integration_query_tip_block() {
    _integration_query_numeric "tip block" tip block
}

test_integration_query_tip_hash() {
    _integration_query tip hash || return 1
    assert_matches "$TEST_LAST_CAPTURE" '^[0-9a-f]+$' "tip hash should be hex" || return 1
}

# --- params ---

test_integration_query_params_min_pool_cost() {
    _integration_query_numeric "minPoolCost" params minPoolCost
}

test_integration_query_params_stake_deposit() {
    _integration_query_numeric "stakeAddressDeposit" params stakeAddressDeposit
}

test_integration_query_params_writes_json() {
    capture_script query.sh params stakeAddressDeposit >/dev/null || return 1
    assert_file_exists "$NETWORK_PATH/params.json" "params.json not written" || return 1
    assert_matches "$(cat "$NETWORK_PATH/params.json")" 'stakeAddressDeposit' "params.json missing stakeAddressDeposit" || return 1
}

# --- metrics ---

test_integration_query_metrics() {
    capture_script query.sh metrics || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "metrics output empty" || return 1
}

test_integration_query_metrics_cardano_series() {
    capture_script query.sh metrics || return 1
    # Chain height (slotNum/blockNum/epoch) appears on many producers; relays often
    # export only operational series under cardano_node_metrics_* (see README metrics filter).
    if echo "$TEST_LAST_CAPTURE" | grep -qE 'cardano_node_metrics_(slotNum|blockNum|epoch)'; then
        return 0
    fi
    if echo "$TEST_LAST_CAPTURE" | grep -qE 'cardano_node_metrics_(nodeStartTime|cardano_build_info|peerSelection)'; then
        return 0
    fi
    echo "metrics output has no expected cardano_node_metrics series"
    return 2
}

# --- config / kes period ---

test_integration_query_config_json() {
    if ! require_network_config "config.json"; then
        echo "config.json not found at $NETWORK_PATH"
        return 1
    fi
    _integration_query config config.json || return 1
    assert_matches "$TEST_LAST_CAPTURE" '"AlonzoGenesisHash"' "config.json should be valid node config" || return 1
}

test_integration_query_kes_period() {
    if ! require_network_config "shelley-genesis.json"; then
        echo "shelley-genesis.json not found at $NETWORK_PATH"
        return 1
    fi
    capture_script query.sh kes_period || return 1
    assert_matches "$TEST_LAST_CAPTURE" 'kesPeriod:' "kes_period output missing kesPeriod" || return 1
    assert_matches "$TEST_LAST_CAPTURE" 'slotsPerKESPeriod:' "kes_period output missing slotsPerKESPeriod" || return 1
}

# --- wallet (optional) ---

test_integration_query_uxto() {
    if ! require_payment_address; then
        echo "payment.addr missing — create keys with docker/fixture.sh address"
        return 2
    fi
    capture_script query.sh uxto || return 1
    return 0
}

test_integration_query_rewards() {
    if ! assert_file_exists "$STAKE_ADDR" >/dev/null 2>&1; then
        echo "stake.addr missing — create keys with docker/fixture.sh address"
        return 2
    fi
    capture_script query.sh rewards || return 1
    assert_matches "$TEST_LAST_CAPTURE" '.' "rewards query returned no content" || return 1
}

test_integration_query_key_payment_addr() {
    if ! require_payment_address; then
        echo "payment.addr key missing"
        return 2
    fi
    _integration_query key payment.addr || return 1
    assert_matches "$TEST_LAST_CAPTURE" 'addr' "payment.addr should contain addr" || return 1
}

# --- producer-only (optional) ---

test_integration_query_kes() {
    if ! require_producer_node; then
        echo "NODE_TYPE=$NODE_TYPE — kes query requires producer"
        return 2
    fi
    if ! assert_file_exists "$NODE_CERT" >/dev/null 2>&1; then
        echo "node.cert missing — create pool keys with docker/fixture.sh spo"
        return 2
    fi
    capture_script query.sh kes || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "kes query returned no output" || return 1
}

test_integration_query_leader_next() {
    if ! require_producer_node; then
        echo "NODE_TYPE=$NODE_TYPE — leader query requires producer"
        return 2
    fi
    if ! assert_file_exists "$POOL_ID" >/dev/null 2>&1; then
        echo "pool.id missing — register pool with docker/fixture.sh spo_register"
        return 2
    fi
    if ! assert_file_exists "$VRF_KEY" >/dev/null 2>&1; then
        echo "vrf.skey missing — create pool keys with docker/fixture.sh spo"
        return 2
    fi
    capture_script query.sh leader next || return 1
    return 0
}

test_integration_node_version() {
    capture_script node.sh version || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "node version empty" || return 1
}
