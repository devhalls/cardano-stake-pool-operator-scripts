#!/bin/bash
# Usage: pool.sh (
#   generate_node_keys |
#   generate_kes_keys |
#   generate_vrf_keys |
#   generate_node_op_cert (kesPeriod <INT>) |
#   generate_pool_reg_cert (pledge <INT>) (cost <FLOAT>) (margin <FLOAT>) (metaUrl <STRING>) (metaHash <STRING>) (--relay <STRING>) [--relay <STRING>] [--type <STRING<'DNS'|'IP'>>] |
#   generate_pool_dreg_cert (epoch <INT>) |
#   generate_pool_meta_hash (url <STRING>) |
#   rotate_kes (startPeriod <INT>) |
#   new_kes (startPeriod <INT>) |
#   get_pool_id [format <STRING<'hex'|'bech32'>>] |
#   get_stake |
#   get_stats |
#   help [-h]
# )
#
# Info:
#
#   - generate_node_keys) Generate node key pair and node counter certificate.
#   - generate_kes_keys) Generate node KES key pair.
#   - generate_vrf_keys) Generate node VRF key pair and sets permissions to 400.
#   - generate_node_op_cert) Generate node operational certificate. Requires the kesPeriod parameter.
#   - generate_pool_reg_cert) Generate pool registration certificate. Requires all params to generate the certificate.
#   - generate_pool_dreg_cert) Generate pool registration certificate.
#   - generate_pool_meta_hash) Generate pools metadata hash from the metadata.json url.
#   - rotate_kes) Rotate the pool KES keys. Requires KES startPeriod as the first parameter.
#   - new_kes) Generate a new pool KES counter. Only use if you need to reset the counter to resolve KES number if incorrect.
#   - get_pool_id) Output the pool ID to $POOL_ID and display it on screen. Optionally pass in the format, defaults to hex.
#   - get_stake) Retrieve pool stats from the blockchain.
#   - get_stats) Retrieve pool stats from js.cexplorer.io.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/common.sh"

# Private functions

_pool_die() {
    print 'ERROR' "$1" $red
    return 1
}

_pool_fail() {
    _pool_die "$1" || return 1
}

_require_cold_node() {
    if is_not_cold_device; then
        _pool_fail 'This command can only be run on a cold device'
    fi
}

_require_producer_node() {
    if is_not_producer_device; then
        _pool_fail 'This command can only be run on a producer device'
    fi
}

_require_param() {
    if [ -z "${1:-}" ]; then
        _pool_fail "Parameter ${2:-unknown} is empty"
    fi
}

_require_file() {
    if [ ! -f "$1" ]; then
        _pool_fail "File $1 does not exist"
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _pool_fail 'Operation cancelled' ;;
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

pool_generate_node_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$NODE_VKEY" "Node keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway node key-gen \
        --cold-verification-key-file $NODE_VKEY \
        --cold-signing-key-file $NODE_KEY \
        --operational-certificate-issue-counter $NODE_COUNTER
    print 'POOL' "Node keys created at $NETWORK_PATH/keys" $green
    return 0
}

pool_generate_node_kes_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$KES_VKEY" "KES keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway node key-gen-KES \
        --verification-key-file $KES_VKEY \
        --signing-key-file $KES_KEY
    print 'POOL' "Node KES keys created at $NETWORK_PATH/keys" $green
    return 0
}

pool_generate_node_vrf_keys() {
    _require_producer_node || return 1
    _require_file_missing_or_confirm "$VRF_VKEY" "VRF keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway node key-gen-VRF \
        --verification-key-file $VRF_VKEY \
        --signing-key-file $VRF_KEY
    chmod 400 $VRF_KEY
    print 'POOL' "Node VRF keys created at $NETWORK_PATH/keys" $green
    return 0
}

pool_generate_node_op_cert() {
    _require_cold_node || return 1
    _require_file "$KES_VKEY" || return 1
    _require_file "$NODE_KEY" || return 1
    _require_file "$NODE_COUNTER" || return 1
    _require_param "${1}" "1 kesPeriod" || return 1
    _require_file_missing_or_confirm "$NODE_CERT" "Certificate already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway node issue-op-cert \
        --kes-verification-key-file $KES_VKEY \
        --cold-signing-key-file $NODE_KEY \
        --operational-certificate-issue-counter $NODE_COUNTER \
        --kes-period ${1} \
        --out-file $NODE_CERT
    print 'POOL' "Node operational certificate created at $NODE_CERT" $green
    return 0
}

pool_generate_pool_reg_cert() {
    _require_cold_node || return 1
    _require_file "$NODE_VKEY" || return 1
    _require_file "$VRF_VKEY" || return 1
    _require_file "$STAKE_VKEY" || return 1
    _require_param "${1}" "1 pledge" || return 1
    _require_param "${2}" "2 cost" || return 1
    _require_param "${3}" "3 margin" || return 1
    _require_param "${4}" "4 metaUrl" || return 1
    _require_param "${5}" "5 metaHash" || return 1
    _require_param "$(get_option --relay "$@")" "--relay" || return 1
    _require_file_missing_or_confirm "$POOL_CERT" "Certificate already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    local pledge="${1}"
    local cost="${2}"
    local margin="${3}"
    local metaUrl="${4}"
    local metaHash="${5}"
    local relayType=$(get_option --type "$@")

    # Format the relays
    local relayArg=''
    local relays=$(get_option --relay "$@")
    echo $relays
    read -ra relayParts <<< "$relays"
    if [ "${#relayParts[@]}" -eq 2 ]; then
        IFS=':' read -r ip port <<< "${relays[0]}"
        if [[ $relayType == *DNS* ]]; then
            relayArg+="--single-host-pool-relay $ip --pool-relay-port $port"
        else
            relayArg+="--pool-relay-ipv4 $ip --pool-relay-port $port"
        fi;
    else
        for ((i=0; i<${#relayParts[@]}; i++)); do
          if [[ "${relayParts[$i]}" == "--relay" ]]; then
            local hostPort="${relayParts[$((i+1))]}"
            IFS=':' read -r host port <<< "$hostPort"
            if [[ $relayType == *DNS* ]]; then
                relayArg+="--single-host-pool-relay $host --pool-relay-port $port "
            else
                relayArg+="--pool-relay-port $port --pool-relay-ipv4 $host "
            fi
          fi
        done
    fi;

    $CNCLI conway stake-pool registration-certificate \
        --cold-verification-key-file $NODE_VKEY \
        --vrf-verification-key-file $VRF_VKEY \
        --pool-pledge $pledge \
        --pool-cost $cost \
        --pool-margin $margin \
        --pool-reward-account-verification-key-file $STAKE_VKEY \
        --pool-owner-stake-verification-key-file $STAKE_VKEY \
        $NETWORK_ARG \
        $relayArg \
        --metadata-url $metaUrl \
        --metadata-hash $metaHash \
        --out-file $POOL_CERT
    print 'POOL' "Node registration certificate created at $POOL_CERT" $green
    return 0
}

pool_generate_pool_dreg_cert() {
    _require_cold_node || return 1
    _require_file "$NODE_VKEY" || return 1
    _require_param "${1}" "1 epoch" || return 1
    _require_file_missing_or_confirm "$POOL_DREG_CERT" "Certificate already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway stake-pool deregistration-certificate \
        --cold-verification-key-file $NODE_VKEY \
        --epoch ${1} \
        --out-file $POOL_DREG_CERT
    print 'POOL' "Node de-registration certificate created at $POOL_DREG_CERT" $green
    return 0
}

pool_generate_pool_meta_hash() {
    _require_producer_node || return 1
    _require_param "${1}" "1 url" || return 1
    local outputFileJson="$(dirname "$0")/../metadata/metadata.json"
    local outputFileHash="$(dirname "$0")/../metadata/metadataHash.txt"
    wget -O $outputFileJson ${1} || _pool_fail 'Could not download pool metadata' || return 1
    _require_file "$outputFileJson" || return 1

    $CNCLI conway stake-pool metadata-hash \
        --pool-metadata-file "${outputFileJson}" >"${outputFileHash}" || _pool_fail 'Could not hash pool metadata' || return 1
    print 'POOL' "Node metadata hash saved to $NODE_HOME/metadata/metadataHash.txt" $green
    print 'POOL' "$(cat $NODE_HOME/metadata/metadataHash.txt)" $green
    return 0
}

pool_rotate_kes() {
    _require_cold_node || return 1
    _require_file "$NODE_KEY" || return 1
    _require_file "$NODE_COUNTER" || return 1
    _require_param "${1}" "1 startPeriod" || return 1
    local startPeriod="${1}"
    _confirm "Please confirm this the correct KES start period: $startPeriod" || return 1

    $CNCLI conway node key-gen-KES \
        --verification-key-file $KES_VKEY \
        --signing-key-file $KES_KEY
    $CNCLI conway node issue-op-cert \
        --kes-verification-key-file $KES_VKEY \
        --cold-signing-key-file $NODE_KEY \
        --operational-certificate-issue-counter $NODE_COUNTER \
        --kes-period $startPeriod \
        --out-file $NODE_CERT
    print 'POOL' "Copy node.cert and kes.skey back to your block producer node and restart it" $green
    return 0
}

pool_new_kes_counter() {
    _require_cold_node || return 1
    _require_file "$NODE_VKEY" || return 1
    local counterValue="${1}"
    $CNCLI conway node new-counter \
        --cold-verification-key-file $NODE_VKEY \
        --counter-value $counterValue \
        --operational-certificate-issue-counter-file $NODE_COUNTER || _pool_fail 'Could not update KES counter' || return 1
    return 0
}

pool_new_kes_counter() {
    exit_if_not_cold
    exit_if_file_missing $NODE_VKEY
    local counterValue="${1}"
    $CNCLI conway node new-counter \
        --cold-verification-key-file $NODE_VKEY \
        --counter-value $counterValue \
        --operational-certificate-issue-counter-file $NODE_COUNTER
}

pool_get_pool_id() {
    _require_cold_node || return 1
    _require_file "$NODE_VKEY" || return 1
    $CNCLI conway stake-pool id \
        --cold-verification-key-file $NODE_VKEY \
        --output-format ${1:-hex} >$POOL_ID
    echo "$(cat $POOL_ID)"
    return 0
}

pool_get_stake() {
    _require_file "$POOL_ID" || return 1
    $CNCLI conway query stake-snapshot --stake-pool-id $(cat $POOL_ID) \
        $NETWORK_ARG --socket-path $NETWORK_SOCKET_PATH
    return $?
}

pool_get_stats() {
    local file=$NETWORK_PATH/stats/data-pool.prom
    local poolId=$(cat "$POOL_ID" 2>/dev/null)
    rm $file 2>/dev/null && touch "$file" && chmod +r $file

    # Add data we can retrieve locally
    # - node version
    local version=$($(dirname "$0")/node.sh version)
    local majorMinor="${version%.*}"
    update_or_append $file "data_nodeVersion" "data_nodeVersion{version=\"$version\"} $majorMinor"

    # Add data we can retrieve locally with pool_id
    # - pool current epoch stake = set
    # - pool -2n epoch stake = mark
    # - pool middle current epoch stake = go
    _require_file "$POOL_ID" || return 1
    local stakeSnapshot=$(pool_get_stake)
    local totalStake=$(echo "$stakeSnapshot" | jq -r ".total.stakeSet")
    local stakeSet=$(echo "$stakeSnapshot" | jq -r ".pools | to_entries[0].value.stakeSet")
    local stakeMark=$(echo "$stakeSnapshot" | jq -r ".pools | to_entries[0].value.stakeMark")
    local stakeGo=$(echo "$stakeSnapshot" | jq -r ".pools | to_entries[0].value.stakeGo")
    update_or_append $file "data_poolStakeSetAda" "data_poolStakeSetAda $stakeSet"
    update_or_append $file "data_poolStakeMarkAda" "data_poolStakeMarkAda $stakeMark"
    update_or_append $file "data_poolStakeGoAda" "data_poolStakeGoAda $stakeGo"

    # Add data we can't retrieve locally using Koios API
    # - Pool saturation, delegators, ledge
    # - Supply network totals, treasury, reserves
    if [ -n "$NODE_KOIOS_API" ]; then

        local poolApiResponse=$(curl -s -X POST "${NODE_KOIOS_API}pool_info" \
            -H "accept: application/json" \
            -H "content-type: application/json" \
            -d '{"_pool_bech32_ids": ["'"$poolId"'"]}')
        if echo "$poolApiResponse" | jq -e 'type == "array"' > /dev/null; then
            local poolApiData=$(echo "$poolApiResponse" | jq '.[-1]')
            update_or_append $file "data_poolPledge" "data_poolPledge $(echo "$poolApiData" | jq -r '.pledge')"
            update_or_append $file "data_poolFixedCost" "data_poolFixedCost $(echo "$poolApiData" | jq -r '.fixed_cost')"
            update_or_append $file "data_poolMargin" "data_poolMargin $(echo "$poolApiData" | jq -r '.margin')"
            update_or_append $file "data_poolLivePledge" "data_poolLivePledge $(echo "$poolApiData" | jq -r '.live_pledge')"
            update_or_append $file "data_poolActiveStake" "data_poolActiveStake $(echo "$poolApiData" | jq -r '.active_stake')"
            update_or_append $file "data_poolLiveStake" "data_poolLiveStake $(echo "$poolApiData" | jq -r '.live_stake')"
            update_or_append $file "data_poolLiveDelegators" "data_poolLiveDelegators $(echo "$poolApiData" | jq -r '.live_delegators')"
            update_or_append $file "data_poolLiveSaturation" "data_poolLiveSaturation $(echo "$poolApiData" | jq -r '.live_saturation')"
            update_or_append $file "data_poolLivePledge" "data_poolLivePledge $(echo "$poolApiData" | jq -r '.live_pledge')"
            update_or_append $file "data_poolBlockCount" "data_poolBlockCount $(echo "$poolApiData" | jq -r '.block_count')"
        fi
        local totalsApiResponse=$(curl -s "${NODE_KOIOS_API}totals?limit=1")
        if echo "$totalsApiResponse" | jq -e 'type == "array"' > /dev/null; then
            local totalsApiData=$(echo "$totalsApiResponse" | jq '.[-1]')
            update_or_append $file "data_totalCirculation" "data_totalCirculation $(echo "$totalsApiData" | jq -r '.circulation // 0')"
            update_or_append $file "data_totalSupply" "data_totalSupply $(echo "$totalsApiData" | jq -r '.supply // 0')"
            update_or_append $file "data_totalTreasury" "data_totalTreasury $(echo "$totalsApiData" | jq -r '.treasury // 0')"
            update_or_append $file "data_totalReserves" "data_totalReserves $(echo "$totalsApiData" | jq -r '.reserves // 0')"
        fi
    fi
    return 0
}

case $1 in
    generate_node_keys) pool_generate_node_keys ;;
    generate_kes_keys) pool_generate_node_kes_keys ;;
    generate_vrf_keys) pool_generate_node_vrf_keys ;;
    generate_node_op_cert) pool_generate_node_op_cert "${@:2}" ;;
    generate_pool_reg_cert) pool_generate_pool_reg_cert "${@:2}" ;;
    generate_pool_dreg_cert) pool_generate_pool_dreg_cert "${@:2}" ;;
    generate_pool_meta_hash) pool_generate_pool_meta_hash "${@:2}" ;;
    rotate_kes) pool_rotate_kes "${@:2}" ;;
    new_kes) pool_new_kes_counter "${@:2}" ;;
    get_pool_id) pool_get_pool_id "${@:2}" ;;
    get_stake) pool_get_stake ;;
    get_stats) pool_get_stats ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
