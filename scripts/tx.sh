#!/bin/bash
# Usage: tx.sh (
#   stake_reg_raw |
#   stake_reg_sign |
#   stake_vote_reg_raw |
#   pool_reg_raw [stakePoolDeposit <INT>] |
#   pool_reg_sign |
#   pool_withdraw_raw |
#   drep_reg_raw |
#   drep_reg_sign |
#   vote_raw [witnesses <INT>] |
#   vote_sign [voteKey <STRING<'node'|'drep'|'cc'>>] |
#   build (amount <INT>) (address <STRING>) [witnesses <INT>] [...params<MIXED>] |
#   sign [...params<MIXED>] |
#   submit |
#   help [-h]
# )
#
# Info:
#
#   - stake_reg_raw) Build raw tx for stake address registration with the stakeAddressDeposit and $STAKE_CERT.
#   - stake_reg_sign) Sign a tx.raw with the $PAYMENT_KEY and $STAKE_KEY (witness-count = 2).
#   - stake_vote_reg_raw) Build raw tx for stake vote registration with $DELE_VOTE_CERT.
#   - pool_reg_raw) Build raw tx for pool registration with the stakePoolDeposit (or passed value) and $POOL_CERT + $DELE_CERT. Optionally pass in stakePoolDeposit to overwrite.
#   - pool_reg_sign) Sign a tx.raw with the $PAYMENT_KEY and $STAKE_KEY and $NODE_KEY (witness-count = 3).
#   - pool_withdraw_raw) Build raw tx for pool withdraw rewards.
#   - drep_reg_raw) Build raw tx for drep registration with the $DREP_CERT.
#   - drep_reg_sign) Sign a tx.raw with the $PAYMENT_KEY and $DREP_KEY (witness-count = 2).
#   - vote_raw) Build raw tx from a vote.raw file (vote.raw is generated using govern.sh functions).
#   - vote_sign) Sign a tx.raw vote transaction with the vote.raw and $PAYMENT_KEY (witness-count = 2).
#   - build) Build a transaction from amount, destination address, witness count, and optional params.
#   - sign) Sign a tx.raw with the passed signing key files.
#   - submit) Submit a tx.signed to chain.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/common.sh"

# Private functions

_tx_die() {
    print 'ERROR' "$1" $red
    return 1
}

_tx_fail() {
    _tx_die "$1" || return 1
}

_require_cold_node() {
    if is_not_cold_device; then
        _tx_fail 'This command can only be run on a cold device'
    fi
}

_require_producer_node() {
    if is_not_producer_device; then
        _tx_fail 'This command can only be run on a producer device'
    fi
}

_require_file() {
    if [ ! -f "$1" ]; then
        _tx_fail "File $1 does not exist"
    fi
}

# Public functions

tx_stake_reg_raw() {
    _require_producer_node || return 1
    paymentAddr=$(cat "${PAYMENT_ADDR}")
    outputPath=$NETWORK_PATH/temp
    currentSlot=$($CNCLI conway query tip $NETWORK_ARG --socket-path $NETWORK_SOCKET_PATH | jq -r '.slot')
    stakeAddressDeposit=$(cat $NETWORK_PATH/params.json | jq -r '.stakeAddressDeposit')
    txIn=""
    totalBalance=0
    txCount=0

    cardano_cli_query_utxo_text "$paymentAddr" "$outputPath/fullUtxo.out"
    cardano_cli_utxo_text_balances "$outputPath/fullUtxo.out" "$outputPath/balance.out"
    cat "$outputPath/balance.out"
    while read -r utxo; do
        if cardano_cli_utxo_line_spendable "$utxo"; then
            inAddr=$(cardano_cli_utxo_text_field "$utxo" txHash)
            idx=$(cardano_cli_utxo_text_field "$utxo" txIx)
            utxoBalance=$(cardano_cli_utxo_text_field "$utxo" lovelace)
            totalBalance=$((${totalBalance} + ${utxoBalance}))
            txIn="${txIn} --tx-in ${inAddr}#${idx}"
        fi
    done <"$outputPath/balance.out"
    txCount=$(wc -l < "$outputPath/balance.out" | tr -d ' ')

    $CNCLI conway transaction build-raw \
        ${txIn} \
        --tx-out ${paymentAddr}+$((${totalBalance} - ${stakeAddressDeposit})) \
        --invalid-hereafter $((${currentSlot} + 10000)) \
        --fee 2000000 \
        --out-file $outputPath/tx.tmp \
        --certificate $STAKE_CERT

    fee=$(parse_cardano_cli_min_fee "$($CNCLI conway transaction calculate-min-fee \
        --tx-body-file $outputPath/tx.tmp \
        --tx-in-count ${txCount} \
        --tx-out-count 1 \
        $NETWORK_ARG \
        --witness-count 2 \
        --byron-witness-count 0 \
        --protocol-params-file $NETWORK_PATH/params.json)")

    txOut=$((${totalBalance} - ${stakeAddressDeposit} - ${fee}))

    $CNCLI conway transaction build-raw \
        ${txIn} \
        --tx-out ${paymentAddr}+${txOut} \
        --invalid-hereafter $((${currentSlot} + 10000)) \
        --fee ${fee} \
        --certificate-file $STAKE_CERT \
        --out-file $outputPath/tx.raw

    rm $outputPath/fullUtxo.out
    rm $outputPath/balance.out
    rm $outputPath/tx.tmp

    print 'TX' "Stake address deposit: ${stakeAddressDeposit}"
    print 'TX' "Available balance: ${totalBalance}"
    print 'TX' "Num of UTXOs: ${txCount}"
    print 'TX' "Fee: ${fee}"
    print 'TX' "Change output: ${txOut}"
    print 'TX' "File output: ${outputPath}/tx.raw" $green
    return 0
}

tx_stake_reg_sign() {
    _require_cold_node || return 1
    outputPath=$NETWORK_PATH/temp

    $CNCLI conway transaction sign \
        --tx-body-file $outputPath/tx.raw \
        --signing-key-file $PAYMENT_KEY \
        --signing-key-file $STAKE_KEY \
        $NETWORK_ARG \
        --out-file $outputPath/tx.signed

    rm $outputPath/tx.raw
    print 'TX' "File output: ${outputPath}/tx.signed" $green
    return 0
}

tx_stake_vote_reg_raw() {
    _require_producer_node || return 1
    outputPath=$NETWORK_PATH/temp

    $CNCLI conway transaction build \
        $NETWORK_ARG \
        --socket-path $NETWORK_SOCKET_PATH \
        --tx-in $(cardano_cli_first_utxo "$(<$PAYMENT_ADDR)") \
        --change-address $(<$PAYMENT_ADDR) \
        --certificate-file $DELE_VOTE_CERT \
        --witness-override 2 \
        --out-file $outputPath/tx.raw

    print 'TX' "File output: ${outputPath}/tx.raw" $green
    return 0
}

tx_pool_reg_raw() {
    _require_producer_node || return 1
    paymentAddr=$(cat "${PAYMENT_ADDR}")
    outputPath=$NETWORK_PATH/temp
    currentSlot=$($CNCLI conway query tip $NETWORK_ARG --socket-path $NETWORK_SOCKET_PATH | jq -r '.slot')
    stakePoolDeposit=${1:-$(cat $NETWORK_PATH/params.json | jq -r '.stakePoolDeposit')}
    txIn=""
    totalBalance=0
    txCount=0

    cardano_cli_query_utxo_text "$paymentAddr" "$outputPath/fullUtxo.out"
    cardano_cli_utxo_text_balances "$outputPath/fullUtxo.out" "$outputPath/balance.out"
    cat "$outputPath/balance.out"
    while read -r utxo; do
        if cardano_cli_utxo_line_spendable "$utxo"; then
            inAddr=$(cardano_cli_utxo_text_field "$utxo" txHash)
            idx=$(cardano_cli_utxo_text_field "$utxo" txIx)
            utxoBalance=$(cardano_cli_utxo_text_field "$utxo" lovelace)
            totalBalance=$((${totalBalance} + ${utxoBalance}))
            txIn="${txIn} --tx-in ${inAddr}#${idx}"
        fi
    done <"$outputPath/balance.out"
    txCount=$(wc -l < "$outputPath/balance.out" | tr -d ' ')

    $CNCLI conway transaction build-raw \
        ${txIn} \
        --tx-out ${paymentAddr}+$((${totalBalance} - ${stakePoolDeposit})) \
        --invalid-hereafter $((${currentSlot} + 10000)) \
        --fee 200000 \
        --certificate-file $POOL_CERT \
        --certificate-file $DELE_CERT \
        --out-file $outputPath/tx.tmp

    fee=$(parse_cardano_cli_min_fee "$($CNCLI conway transaction calculate-min-fee \
        --tx-body-file $outputPath/tx.tmp \
        --tx-in-count ${txCount} \
        --tx-out-count 1 \
        $NETWORK_ARG \
        --witness-count 3 \
        --byron-witness-count 0 \
        --protocol-params-file $NETWORK_PATH/params.json)")

    txOut=$((${totalBalance} - ${stakePoolDeposit} - ${fee}))

    $CNCLI conway transaction build-raw \
        ${txIn} \
        --tx-out ${paymentAddr}+${txOut} \
        --invalid-hereafter $((${currentSlot} + 10000)) \
        --fee ${fee} \
        --certificate-file $POOL_CERT \
        --certificate-file $DELE_CERT \
        --out-file $outputPath/tx.raw

    rm $outputPath/fullUtxo.out
    rm $outputPath/balance.out
    rm $outputPath/tx.tmp

    print 'TX' "Stake pool deposit: ${stakePoolDeposit}"
    print 'TX' "Available balance: ${totalBalance}"
    print 'TX' "Num of UTXOs: ${txCount}"
    print 'TX' "Fee: ${fee}"
    print 'TX' "Change output: ${txOut}"
    print 'TX' "File output: ${outputPath}/tx.raw" $green
    return 0
}

tx_pool_reg_sign() {
    _require_cold_node || return 1
    outputPath=$NETWORK_PATH/temp

    $CNCLI conway transaction sign \
        --tx-body-file $outputPath/tx.raw \
        --signing-key-file $PAYMENT_KEY \
        --signing-key-file $NODE_KEY \
        --signing-key-file $STAKE_KEY \
        $NETWORK_ARG \
        --out-file $outputPath/tx.signed

    rm $outputPath/tx.raw
    print 'TX' "File output: ${outputPath}/tx.signed" $green
    return 0
}

tx_pool_withdraw_raw() {
    _require_producer_node || return 1
    outputPath=$NETWORK_PATH/temp/tx.raw
    rewards="$(bash $(dirname "$0")/query.sh rewards rewardAccountBalance)"

    $CNCLI conway transaction build \
        $NETWORK_ARG \
        --socket-path $NETWORK_SOCKET_PATH \
        --tx-in $(cardano_cli_first_utxo "$(<$PAYMENT_ADDR)") \
        --withdrawal "$(<$STAKE_ADDR)+$rewards" \
        --change-address $(<$PAYMENT_ADDR) \
        --witness-override 2 \
        --out-file $outputPath

    print 'TX' "File output: $outputPath" $green
    return 0
}

tx_drep_reg_raw() {
    _require_producer_node || return 1
    outputPath=$NETWORK_PATH/temp

    $CNCLI conway transaction build \
        $NETWORK_ARG \
        --socket-path $NETWORK_SOCKET_PATH \
        --tx-in $(cardano_cli_first_utxo "$(<$PAYMENT_ADDR)") \
        --change-address $(<$PAYMENT_ADDR) \
        --certificate-file $DREP_CERT \
        --witness-override 2 \
        --out-file $outputPath/tx.raw

    print 'TX' "File output: ${outputPath}/tx.raw" $green
    return 0
}

tx_drep_reg_sign() {
    _require_cold_node || return 1
    outputPath=$NETWORK_PATH/temp

    $CNCLI conway transaction sign \
        $NETWORK_ARG \
        --tx-body-file $outputPath/tx.raw \
        --signing-key-file $PAYMENT_KEY \
        --signing-key-file $DREP_KEY \
        --out-file $outputPath/tx.signed

    rm $outputPath/tx.raw
    print 'TX' "File output: ${outputPath}/tx.signed" $green
    return 0
}

tx_vote_raw() {
    _require_producer_node || return 1
    local witnesses=${1:-2}
    local tempPath=$NETWORK_PATH/temp
    local votePath=$tempPath/vote.raw
    local outPath=$tempPath/tx.raw
    _require_file "$votePath" || return 1

    $CNCLI conway transaction build \
        $NETWORK_ARG --socket-path $NETWORK_SOCKET_PATH \
        --tx-in $(cardano_cli_first_utxo "$(<$PAYMENT_ADDR)") \
        --change-address $(<$PAYMENT_ADDR) \
        --vote-file $votePath \
        --witness-override $witnesses \
        --out-file $outPath || _tx_fail "Failed to build transaction from $votePath" || return 1

    rm $votePath
    print 'TX' "File output: $outPath" $green
    return 0
}

tx_vote_sign() {
    _require_cold_node || return 1
    local keyFile=${1:-'node'}
    local tempPath=$NETWORK_PATH/temp
    local votePath=$tempPath/tx.raw
    local outPath=$tempPath/tx.signed
    _require_file "$votePath" || return 1

    local verificationArg=
    case $keyFile in
        "node") verificationArg="--signing-key-file $NODE_KEY" ;;
        "drep") verificationArg="--signing-key-file $DREP_KEY" ;;
        "cc") verificationArg="--signing-key-file $CC_HOT_KEY" ;;
        *) _tx_fail "Incorrect voteKey value $keyFile: allowed values 'node' | 'drep' | 'cc'" || return 1 ;;
    esac

    $CNCLI conway transaction sign \
        --tx-body-file $votePath \
        $verificationArg \
        --signing-key-file $PAYMENT_KEY \
        --out-file $outPath || _tx_fail "Failed to sign transaction at $votePath" || return 1

    rm $votePath
    print 'TX' "File output: $outPath" $green
    return 0
}

tx_in() {
    outputPath=$NETWORK_PATH/temp
    totalBalance=0
    txCount=0
    txIn=""

    # Calculate.
    bash "$(dirname "$0")/query.sh" uxto >"$outputPath/uxto.out"
    cardano_cli_utxo_text_balances "$outputPath/uxto.out" "$outputPath/balance.out"
    cat "$outputPath/balance.out"
    while read -r utxo; do
        if cardano_cli_utxo_line_spendable "$utxo"; then
            inAddr=$(cardano_cli_utxo_text_field "$utxo" txHash)
            idx=$(cardano_cli_utxo_text_field "$utxo" txIx)
            utxoBalance=$(cardano_cli_utxo_text_field "$utxo" lovelace)
            totalBalance=$((${totalBalance} + ${utxoBalance}))
            txIn="${txIn} --tx-in ${inAddr}#${idx}"
        fi
    done <"$outputPath/balance.out"

    # Output.
    echo totalBalance: ${totalBalance}
    echo txCount: $(wc -l < "$outputPath/balance.out" | tr -d ' ')
    echo txIn: ${txIn}

    # Clean up.
    rm $outputPath/uxto.out
    rm $outputPath/balance.out
    return 0
}

tx_out() {
    amount=${1}
    destinationAddress=${2}
    totalBalance=${3}
    txCount=${4}
    witnessCount=${5}
    txIn=$(get_option --tx-in "${@:6}")
    params=${@:8}

    # get_option returns only values; build --tx-in VALUE for each UTXO
    txInArgs=""
    for v in $txIn; do
        txInArgs="$txInArgs --tx-in $v"
    done

    paymentAddress=$(<$PAYMENT_ADDR)
    currentSlot=$(bash $(dirname "$0")/query.sh tip slot)
    outputPath=$NETWORK_PATH/temp
    mkdir -p "$outputPath"

    # Calculate the fee (tx must include both destination and change outputs for correct size).
    $CNCLI conway transaction build-raw \
        $txInArgs \
        --tx-out ${destinationAddress}+${amount} \
        --tx-out ${paymentAddress}+$((${totalBalance} - ${amount})) \
        --invalid-hereafter $((${currentSlot} + 10000)) \
        --fee 0 \
        --out-file $outputPath/tx.tmp \
        ${params}

    fee=$(parse_cardano_cli_min_fee "$($CNCLI conway transaction calculate-min-fee \
        --tx-body-file $outputPath/tx.tmp \
        --tx-in-count ${txCount} \
        --tx-out-count 2 \
        $NETWORK_ARG \
        --witness-count $witnessCount \
        --byron-witness-count 0 \
        --protocol-params-file $NETWORK_PATH/params.json)")
    txOut=$((${totalBalance} - ${amount} - ${fee}))

    # Build the tx.raw (destination output + change output).
    $CNCLI conway transaction build-raw \
        $txInArgs \
        --tx-out ${destinationAddress}+${amount} \
        --tx-out ${paymentAddress}+${txOut} \
        --invalid-hereafter $((${currentSlot} + 10000)) \
        --fee ${fee} \
        ${params} \
        --out-file $outputPath/tx.raw

    # Output.
    echo fee: $fee
    echo txRaw: $outputPath/tx.raw

    # Clean up.
    rm $outputPath/tx.tmp
    return 0
}

tx_build() {
    amount=${1:-0}
    destination=${2}
    witnessCount=${3}
    params="${@:4}"

    # Calculate tx input.
    txInput=$(tx_in)
    totalBalance=$(get_param "$txInput" "totalBalance")
    txCount=$(get_param "$txInput" "txCount")
    txIn=$(get_param "$txInput" "txIn")

    # Calculate tx fee and tx.raw.
    txOutput=$(tx_out $amount $destination $totalBalance $txCount $witnessCount $txIn $params)

    fee=$(get_param "$txOutput" "fee")
    txRaw=$(get_param "$txOutput" "txRaw")

    # Output.
    echo fee: $fee
    print 'TX' "File output: $txRaw" $green
    return 0
}

tx_sign() {
    signingKeyFiles=$(get_option --signing-key-file "$@")
    # get_option returns only values; build --signing-key-file PATH for each
    signers=""
    for f in $signingKeyFiles; do
        signers="$signers --signing-key-file $f"
    done
    tempPath=$NETWORK_PATH/temp
    votePath=$NETWORK_PATH/temp/vote.raw

    $CNCLI conway transaction sign \
        --tx-body-file $tempPath/tx.raw \
        $signers \
        --out-file $tempPath/tx.signed

    rm $tempPath/tx.raw
    print 'TX' "File output: $tempPath/tx.signed" $green
    return 0
}

tx_submit() {
    _require_producer_node || return 1
    outputPath=$NETWORK_PATH/temp

    $CNCLI conway transaction submit \
        --tx-file $outputPath/tx.signed \
        --socket-path $NETWORK_SOCKET_PATH \
        $NETWORK_ARG

    rm $outputPath/tx.signed
    return 0
}

case $1 in
    stake_reg_raw) tx_stake_reg_raw ;;
    stake_reg_sign) tx_stake_reg_sign ;;
    stake_vote_reg_raw) tx_stake_vote_reg_raw ;;
    pool_reg_raw) tx_pool_reg_raw "${@:2}" ;;
    pool_reg_sign) tx_pool_reg_sign ;;
    pool_withdraw_raw) tx_pool_withdraw_raw ;;
    drep_reg_raw) tx_drep_reg_raw ;;
    drep_reg_sign) tx_drep_reg_sign ;;
    vote_raw) tx_vote_raw "${@:2}" ;;
    vote_sign) tx_vote_sign "${@:2}" ;;
    build) tx_build "${@:2}" ;;
    sign) tx_sign "${@:2}" ;;
    submit) tx_submit ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
