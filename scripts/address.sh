#!/bin/bash
# Usage: address.sh (
#   generate_payment_keys |
#   generate_stake_keys |
#   generate_payment_address |
#   generate_stake_address |
#   generate_stake_reg_cert [deposit <INT>] |
#   generate_stake_del_cert |
#   generate_stake_vote_cert (delegateTo <STRING<'drep'|'script'|'abstain'|'no-confidence'>>) |
#   help [-h]
# )
#
# Info:
#
#   - generate_payment_keys) Generate a payment key pair.
#   - generate_stake_keys) Generate a stake key pair.
#   - generate_payment_address) Generate a payment address from a payment key.
#   - generate_stake_address) Generate a stake address from a stake key.
#   - generate_stake_reg_cert) Generate a stake registration certificate. Requires the deposit param in lovelace.
#   - generate_stake_del_cert) Generate a stake delegation certificate.
#   - generate_stake_vote_cert) Generate a vote delegation certificate delegating your voting power. Can be 'drep <drepId>' | 'script <scriptHash>' | 'abstain' | 'no-confidence'.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/common.sh"

# Private functions

_address_die() {
    print 'ERROR' "$1" $red
    return 1
}

_address_fail() {
    _address_die "$1" || return 1
}

_require_cold_node() {
    if is_not_cold_device; then
        _address_fail 'This command can only be run on a cold device'
    fi
}

_require_producer_node() {
    if is_not_producer_device; then
        _address_fail 'This command can only be run on a producer device'
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _address_fail 'Operation cancelled' ;;
    esac
}

_require_file_missing_or_confirm() {
    local file="$1"
    local message="$2"
    if [ -f "$file" ]; then
        _confirm "$message" || return 1
    fi
    return 0
}

# Public functions

address_generate_payment_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$PAYMENT_KEY" "Payment keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway address key-gen \
        --verification-key-file $PAYMENT_VKEY \
        --signing-key-file $PAYMENT_KEY || _address_fail 'Could not generate payment keys' || return 1
    print 'ADDRESS' "Payment keys created at $NETWORK_PATH/keys" $green
    return 0
}

address_generate_stake_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$STAKE_KEY" "Stake keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway stake-address key-gen \
        --verification-key-file $STAKE_VKEY \
        --signing-key-file $STAKE_KEY || _address_fail 'Could not generate stake keys' || return 1
    print 'ADDRESS' "Stake keys created at $NETWORK_PATH/keys" $green
    return 0
}

address_generate_payment_address() {
    _require_producer_node || return 1
    _require_file_missing_or_confirm "$PAYMENT_ADDR" "Payment address already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway address build \
        --payment-verification-key-file $PAYMENT_VKEY \
        --stake-verification-key-file $STAKE_VKEY \
        --out-file $PAYMENT_ADDR \
        $NETWORK_ARG || _address_fail 'Could not generate payment address' || return 1
    print 'ADDRESS' "Payment address: $(cat $PAYMENT_ADDR)" $green
    return 0
}

address_generate_stake_address() {
    _require_producer_node || return 1
    _require_file_missing_or_confirm "$STAKE_ADDR" "Stake address already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway stake-address build \
        --stake-verification-key-file $STAKE_VKEY \
        --out-file $STAKE_ADDR \
        $NETWORK_ARG || _address_fail 'Could not generate stake address' || return 1
    print 'ADDRESS' "Stake address: $(cat $STAKE_ADDR)" $green
    return 0
}

address_generate_stake_reg_cert() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$STAKE_CERT" "Certificate already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway stake-address registration-certificate \
        --stake-verification-key-file $STAKE_VKEY \
        --key-reg-deposit-amt $1 \
        --out-file $STAKE_CERT || _address_fail 'Could not generate stake registration certificate' || return 1
    print 'ADDRESS' "Stake registration certificate created at $STAKE_CERT" $green
    return 0
}

address_generate_stake_del_cert() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$DELE_CERT" "Certificate already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway stake-address stake-delegation-certificate \
        --stake-verification-key-file $STAKE_VKEY \
        --cold-verification-key-file $NODE_VKEY \
        --out-file $DELE_CERT || _address_fail 'Could not generate stake delegation certificate' || return 1
    print 'ADDRESS' "Stake delegation certificate created at $DELE_CERT" $green
    return 0
}

address_generate_stake_vote_cert() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$DELE_VOTE_CERT" "Certificate already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    local param=
    case $1 in
        drep) param="--drep-key-hash $2" ;;
        script) param="--drep-script-hash $2" ;;
        abstain) param="--always-abstain" ;;
        no-confidence) param="--always-no-confidence" ;;
        *) _address_fail "Incorrect delegateTo value $1: allowed values 'drep' | 'script' | 'abstain' | 'no-confidence'" || return 1 ;;
    esac
    $CNCLI conway stake-address vote-delegation-certificate \
        --stake-verification-key-file $STAKE_VKEY \
        $param \
        --out-file $DELE_VOTE_CERT || _address_fail 'Could not generate vote delegation certificate' || return 1
    print 'ADDRESS' "Voting delegation certificate created for: $@" $green
    return 0
}

case $1 in
    generate_payment_keys) address_generate_payment_keys ;;
    generate_payment_address) address_generate_payment_address ;;
    generate_stake_keys) address_generate_stake_keys ;;
    generate_stake_address) address_generate_stake_address ;;
    generate_stake_reg_cert) address_generate_stake_reg_cert "${@:2}" ;;
    generate_stake_del_cert) address_generate_stake_del_cert ;;
    generate_stake_vote_cert) address_generate_stake_vote_cert "${@:2}" ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
