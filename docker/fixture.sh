#!/bin/bash
# Usage: fixture.sh [
#   address |
#   address_register |
#   spo |
#   spo_register [relayAddress <IP_ADDRESS>] [relayPort <INT>] [metadataUrl <STRING>] |
#   drep |
#   drep_register [metadataUrl <STRING>] |
#   drep_delegate |
#   help [-h]
# ]
#
# Info:
#
#   - address) Generate payment and stake key and a payment and stake address.
#   - address_register) Register stake addresses and deposit.
#   - spo) Generate SPO credentials allow for a producer node.
#   - spo_register) Register stake addresses and deposit.
#   - drep) Generate DRep credentials and certificate.
#   - drep_register) Register DRep certificate.
#   - help) View this files help. Default value if no option is passed.

set -e

help() {
    echo -e $orange
    sed -ne '/^#/!q;s/^#$/# /;/^# /s/^# //p' <"$0" |
        awk -v f="${1#-h}" '!f && /^Usage:/ || u { u=!/^\s*$/; if (!u) exit } u || f'
    echo -e $nc
    exit 1
}

address_keys() {
    ./docker/script.sh address.sh generate_payment_keys
    ./docker/script.sh address.sh generate_stake_keys
    ./docker/script.sh address.sh generate_payment_address
    ./docker/script.sh address.sh generate_stake_address
    echo "You can now transfer yourself testnet ada using the faucet:"
    echo "https://docs.cardano.org/cardano-testnets/tools/faucet"
}

address_register() {
    lovelace=$(./docker/script.sh query.sh params stakeAddressDeposit)
    ./docker/script.sh address.sh generate_stake_reg_cert $lovelace
    ./docker/script.sh tx.sh stake_reg_raw
    ./docker/script.sh tx.sh stake_reg_sign
    ./docker/script.sh tx.sh submit
}

spo_keys() {
    ./docker/script.sh query.sh params
    kes=$(./docker/script.sh query.sh kes_period)
    kesPeriod=$(echo "$kes" | awk 'END {print $2}')
    ./docker/script.sh pool.sh generate_kes_keys
    ./docker/script.sh pool.sh generate_node_keys
    ./docker/script.sh pool.sh generate_node_op_cert $kesPeriod
    ./docker/script.sh pool.sh generate_vrf_keys
}

spo_register() {
    relayAddr="${1}"
    relayPort="${2}"
    metaUrl="${3}"
    hash=$(./docker/script.sh pool.sh generate_pool_meta_hash)
    minPoolCost=$(./docker/script.sh query.sh params minPoolCost)
    ./docker/script.sh pool.sh generate_pool_reg_cert $minPoolCost $minPoolCost 0.01 $relayAddr $relayPort $metaUrl $hash
    ./docker/script.sh address.sh generate_stake_del_cert
    ./docker/script.sh tx.sh pool_reg_raw
    ./docker/script.sh tx.sh pool_reg_sign
    ./docker/script.sh tx.sh submit
    ./docker/script.sh pool.sh get_pool_id
}

drep_keys() {
    metaUrl="${1}"
    ./docker/script.sh govern.sh drep_keys
    ./docker/script.sh govern.sh drep_id
    ./docker/script.sh govern.sh drep_cert $metaUrl
}

drep_register() {
    ./docker/script.sh tx.sh drep_reg_raw
    ./docker/script.sh tx.sh drep_reg_sign
    ./docker/script.sh tx.sh submit
}

drep_delegate() {
    source "$(dirname "$0")/../env.docker"
    drepId=$(./docker/script.sh govern.sh drep_id)
    ./docker/script.sh address.sh generate_stake_vote_cert drep $drepId
    ./docker/script.sh tx.sh build 0 2 --certificate-file "$DELE_VOTE_CERT"
    ./docker/script.sh tx.sh sign --signing-key-file "$PAYMENT_KEY" --signing-key-file "$STAKE_KEY"
    ./docker/script.sh tx.sh submit
}

case $1 in
    address) address_keys ;;
    address_register) address_register ;;
    spo) spo_keys ;;
    spo_register) spo_register "${@:2}" ;;
    drep) drep_keys "${@:2}" ;;
    drep_register) drep_register "${@:2}" ;;
    drep_delegate) drep_delegate "${@:2}" ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
