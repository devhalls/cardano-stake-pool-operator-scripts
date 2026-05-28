#!/bin/bash
# Fixture-parity destructive tests — mirror docker/fixture.sh flows.
# Not wired into test.sh (smoke + integration only). Re-enable by sourcing from test.sh.

# Defaults for spo_register when args omitted
FIXTURE_RELAY_ADDR="${FIXTURE_RELAY_ADDR:-${NODE_HOSTADDR:-127.0.0.1}}"
FIXTURE_RELAY_PORT="${FIXTURE_RELAY_PORT:-${NODE_PORT:-6000}}"
FIXTURE_METADATA_URL="${FIXTURE_METADATA_URL:-}"

run_suite_fixture() {
    local sub="${1:-}"

    if ! require_socket; then
        skip_test fixture_suite "node socket not available at $NETWORK_SOCKET_PATH"
        return 0
    fi

    case "$sub" in
        address)
            run_fixture_address_keys
            ;;
        address_register)
            run_fixture_address_register
            ;;
        spo)
            run_fixture_spo_keys
            ;;
        spo_register)
            run_fixture_spo_register "${@:2}"
            ;;
        drep)
            run_fixture_drep_keys "${@:2}"
            ;;
        drep_register)
            run_fixture_drep_register
            ;;
        drep_delegate)
            run_fixture_drep_delegate
            ;;
        "")
            run_fixture_address_keys
            run_fixture_address_register
            run_fixture_spo_keys
            run_fixture_spo_register
            run_fixture_drep_keys
            run_fixture_drep_register
            run_fixture_drep_delegate
            ;;
        *)
            echo "Unknown fixture subcommand: $sub"
            return 1
            ;;
    esac
}

list_suite_fixture() {
    echo "fixture (destructive, requires socket; optional subcommand):"
    echo "  address | address_register | spo | spo_register | drep | drep_register | drep_delegate"
    echo "  (no subcommand runs full fixture flow)"
}

run_fixture_address_keys() {
    if ! require_keys_missing; then
        skip_test fixture_address_keys "payment/stake keys already exist"
        return 0
    fi
    run_test fixture_address_generate_payment_keys test_fixture_address_generate_payment_keys
    run_test fixture_address_generate_stake_keys test_fixture_address_generate_stake_keys
    run_test fixture_address_generate_payment_address test_fixture_address_generate_payment_address
    run_test fixture_address_generate_stake_address test_fixture_address_generate_stake_address
}

run_fixture_address_register() {
    if ! require_payment_keys; then
        skip_test fixture_address_register "payment/stake keys missing — run fixture address first"
        return 0
    fi
    if ! require_funded_wallet; then
        skip_test fixture_address_register "wallet not funded — use testnet faucet"
        return 0
    fi
    run_test fixture_address_stake_reg_cert test_fixture_address_stake_reg_cert
    run_test fixture_address_stake_reg_raw test_fixture_address_stake_reg_raw
    run_test fixture_address_stake_reg_sign test_fixture_address_stake_reg_sign
    run_test fixture_address_stake_reg_submit test_fixture_address_stake_reg_submit
}

run_fixture_spo_keys() {
    run_test fixture_spo_query_params test_fixture_spo_query_params
    run_test fixture_spo_kes_period test_fixture_spo_kes_period
    run_test fixture_spo_generate_kes_keys test_fixture_spo_generate_kes_keys
    run_test fixture_spo_generate_node_keys test_fixture_spo_generate_node_keys
    run_test fixture_spo_generate_node_op_cert test_fixture_spo_generate_node_op_cert
    run_test fixture_spo_generate_vrf_keys test_fixture_spo_generate_vrf_keys
}

run_fixture_spo_register() {
    local relay_addr="${1:-$FIXTURE_RELAY_ADDR}"
    local relay_port="${2:-$FIXTURE_RELAY_PORT}"
    local meta_url="${3:-$FIXTURE_METADATA_URL}"

    if [ -z "$meta_url" ]; then
        skip_test fixture_spo_register "metadata URL required: test.sh fixture spo_register <relay> <port> <metadataUrl>"
        return 0
    fi
    if ! require_payment_keys; then
        skip_test fixture_spo_register "keys missing — run address fixture first"
        return 0
    fi

    FIXTURE_SPO_RELAY="$relay_addr"
    FIXTURE_SPO_PORT="$relay_port"
    FIXTURE_SPO_META="$meta_url"

    run_test fixture_spo_pool_meta_hash test_fixture_spo_pool_meta_hash
    run_test fixture_spo_pool_reg_cert test_fixture_spo_pool_reg_cert
    run_test fixture_spo_stake_del_cert test_fixture_spo_stake_del_cert
    run_test fixture_spo_pool_reg_raw test_fixture_spo_pool_reg_raw
    run_test fixture_spo_pool_reg_sign test_fixture_spo_pool_reg_sign
    run_test fixture_spo_pool_reg_submit test_fixture_spo_pool_reg_submit
    run_test fixture_spo_get_pool_id test_fixture_spo_get_pool_id
}

run_fixture_drep_keys() {
    local meta_url="${1:-$FIXTURE_METADATA_URL}"
    if [ -z "$meta_url" ]; then
        skip_test fixture_drep_keys "metadata URL required: test.sh fixture drep <metadataUrl>"
        return 0
    fi
    FIXTURE_DREP_META="$meta_url"
    run_test fixture_drep_keys_gen test_fixture_drep_keys_gen
    run_test fixture_drep_id test_fixture_drep_id
    run_test fixture_drep_cert test_fixture_drep_cert
}

run_fixture_drep_register() {
    if ! require_drep_keys; then
        skip_test fixture_drep_register "drep keys missing — run fixture drep first"
        return 0
    fi
    run_test fixture_drep_reg_raw test_fixture_drep_reg_raw
    run_test fixture_drep_reg_sign test_fixture_drep_reg_sign
    run_test fixture_drep_reg_submit test_fixture_drep_reg_submit
}

run_fixture_drep_delegate() {
    if ! require_drep_keys; then
        skip_test fixture_drep_delegate "drep keys missing"
        return 0
    fi
    if ! require_payment_keys; then
        skip_test fixture_drep_delegate "payment/stake keys missing"
        return 0
    fi
    run_test fixture_drep_delegate_vote_cert test_fixture_drep_delegate_vote_cert
    run_test fixture_drep_delegate_tx_build test_fixture_drep_delegate_tx_build
    run_test fixture_drep_delegate_tx_sign test_fixture_drep_delegate_tx_sign
    run_test fixture_drep_delegate_tx_submit test_fixture_drep_delegate_tx_submit
}

# --- address steps ---

test_fixture_address_generate_payment_keys() {
    capture_script address.sh generate_payment_keys || return 1
}

test_fixture_address_generate_stake_keys() {
    capture_script address.sh generate_stake_keys || return 1
}

test_fixture_address_generate_payment_address() {
    capture_script address.sh generate_payment_address || return 1
    assert_file_exists "$PAYMENT_ADDR" || return 1
}

test_fixture_address_generate_stake_address() {
    capture_script address.sh generate_stake_address || return 1
    assert_file_exists "$STAKE_ADDR" || return 1
}

test_fixture_address_stake_reg_cert() {
    local lovelace
    lovelace="$(capture_script query.sh params stakeAddressDeposit)" || return 1
    capture_script address.sh generate_stake_reg_cert "$lovelace" || return 1
}

test_fixture_address_stake_reg_raw() { capture_script tx.sh stake_reg_raw || return 1; }
test_fixture_address_stake_reg_sign() { capture_script tx.sh stake_reg_sign || return 1; }
test_fixture_address_stake_reg_submit() { capture_script tx.sh submit || return 1; }

# --- spo steps ---

test_fixture_spo_query_params() { capture_script query.sh params || return 1; }

test_fixture_spo_kes_period() {
    capture_script query.sh kes_period || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" || return 1
    FIXTURE_KES_PERIOD="$(echo "$TEST_LAST_CAPTURE" | awk 'END {print $2}')"
    assert_nonempty "$FIXTURE_KES_PERIOD" "could not parse KES period" || return 1
}

test_fixture_spo_generate_kes_keys() { capture_script pool.sh generate_kes_keys || return 1; }
test_fixture_spo_generate_node_keys() { capture_script pool.sh generate_node_keys || return 1; }

test_fixture_spo_generate_node_op_cert() {
    assert_nonempty "$FIXTURE_KES_PERIOD" "KES period not set — run fixture_spo_kes_period first" || return 1
    capture_script pool.sh generate_node_op_cert "$FIXTURE_KES_PERIOD" || return 1
}

test_fixture_spo_generate_vrf_keys() { capture_script pool.sh generate_vrf_keys || return 1; }

test_fixture_spo_pool_meta_hash() { capture_script pool.sh generate_pool_meta_hash || return 1; }

test_fixture_spo_pool_reg_cert() {
    local hash min_pool
    hash="$(capture_script pool.sh generate_pool_meta_hash)" || return 1
    min_pool="$(capture_script query.sh params minPoolCost)" || return 1
    capture_script pool.sh generate_pool_reg_cert "$min_pool" "$min_pool" 0.01 \
        "$FIXTURE_SPO_RELAY" "$FIXTURE_SPO_PORT" "$FIXTURE_SPO_META" "$hash" || return 1
}

test_fixture_spo_stake_del_cert() { capture_script address.sh generate_stake_del_cert || return 1; }
test_fixture_spo_pool_reg_raw() { capture_script tx.sh pool_reg_raw || return 1; }
test_fixture_spo_pool_reg_sign() { capture_script tx.sh pool_reg_sign || return 1; }
test_fixture_spo_pool_reg_submit() { capture_script tx.sh submit || return 1; }

test_fixture_spo_get_pool_id() {
    capture_script pool.sh get_pool_id || return 1
    assert_nonempty "$TEST_LAST_CAPTURE" || return 1
}

# --- drep steps ---

test_fixture_drep_keys_gen() { capture_script govern.sh drep_keys || return 1; }

test_fixture_drep_id() {
    capture_script govern.sh drep_id || return 1
    FIXTURE_DREP_ID="$TEST_LAST_CAPTURE"
    assert_nonempty "$FIXTURE_DREP_ID" || return 1
}

test_fixture_drep_cert() {
    capture_script govern.sh drep_cert "$FIXTURE_DREP_META" || return 1
}

test_fixture_drep_reg_raw() { capture_script tx.sh drep_reg_raw || return 1; }
test_fixture_drep_reg_sign() { capture_script tx.sh drep_reg_sign || return 1; }
test_fixture_drep_reg_submit() { capture_script tx.sh submit || return 1; }

test_fixture_drep_delegate_vote_cert() {
    local drep_id
    drep_id="$(capture_script govern.sh drep_id)" || return 1
    capture_script address.sh generate_stake_vote_cert drep "$drep_id" || return 1
}

test_fixture_drep_delegate_tx_build() {
    capture_script tx.sh build 0 2 --certificate-file "$DELE_VOTE_CERT" || return 1
}

test_fixture_drep_delegate_tx_sign() {
    capture_script tx.sh sign \
        --signing-key-file "$PAYMENT_KEY" \
        --signing-key-file "$STAKE_KEY" || return 1
}

test_fixture_drep_delegate_tx_submit() {
    capture_script tx.sh submit || return 1
}
