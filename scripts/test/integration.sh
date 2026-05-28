#!/bin/bash
# Integration tests — require a running node and socket.

run_suite_integration() {
    if ! require_socket; then
        skip_test integration_suite "node socket not available at $NETWORK_SOCKET_PATH"
        return 0
    fi

    run_test integration_query_tip_slot test_integration_query_tip_slot
    run_test integration_query_params_min_pool_cost test_integration_query_params_min_pool_cost
    run_test integration_query_metrics test_integration_query_metrics
    run_test integration_node_version test_integration_node_version
}

list_suite_integration() {
    echo "integration (requires socket):"
    echo "  integration_query_tip_slot"
    echo "  integration_query_params_min_pool_cost"
    echo "  integration_query_metrics"
    echo "  integration_node_version"
}

test_integration_query_tip_slot() {
    capture_script query.sh tip slot || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "tip slot empty" || return 1
    assert_matches "$TEST_LAST_CAPTURE" '^[0-9]+$' "tip slot should be numeric" || return 1
}

test_integration_query_params_min_pool_cost() {
    capture_script query.sh params minPoolCost || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "minPoolCost empty" || return 1
    assert_matches "$TEST_LAST_CAPTURE" '^[0-9]+$' "minPoolCost should be numeric" || return 1
}

test_integration_query_metrics() {
    capture_script query.sh metrics || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "metrics output empty" || return 1
}

test_integration_node_version() {
    capture_script node.sh version || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" "node version empty" || return 1
}
