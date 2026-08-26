#!/bin/bash
# Usage: query.sh (
#   tip [name <STRING>] |
#   params [name <STRING>] |
#   state (name <STRING>) |
#   metrics [name <STRING>] |
#   config (name <STRING>) |
#   key (name <STRING>) |
#   keys (format <STRING<'table'>>)|
#   kes |
#   kes_period |
#   uxto [address <STRING>] |
#   leader [period <STRING<'current'|'next'>>] |
#   leader_next |
#   rewards [name <STRING>] |
#   help [-h]
# )
#
# Info:
#
#   - tip) Query the blockchain tip. Optionally pass a param name to view only this value.
#   - params) Query the blockchain protocol parameters and saves these to $NETWORK_PATH/params.json. Optionally pass a param name to view only this value.
#   - state) Query the blockchain ledger-state and saves these to $NETWORK_PATH/ledger.json. Optionally pass a param name to view only this value. Very large so we only create it if it does not exist (will become out of date if left as is, you must periodically delete the ledger.json file.)
#   - metrics) Query the prometheus metrics. Optionally pass a param name to view only this value.
#   - config) Echo the contents of any config file located in $NETWORK_PATH. Pass the file name you wish to read.
#   - key) Echo the contents of any file located in $NETWORK_PATH/keys. Pass the file name you wish to read.
#   - keys) Echo the contents of all files located in $NETWORK_PATH/keys.
#   - kes) Query the current $NODE_CERT on chain kes state.
#   - kes_period) Query the kes period params. Useful when generating pool certificates.
#   - uxto) Query the uxto for an address. Defaults to $PAYMENT_ADDR if non is passed.
#   - leader) Run the pool leader slot query. Pass the period to choose which epoch to query ['next' | 'current' ].
#   - leader_next) Query next-epoch leadership slots when at least 75% of the current epoch has passed. Skips if already ran (epoch temp file present). Intended for crontab; the function controls timing.
#   - rewards) Query stake address info. Optionally pass a param name to view only this value.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/common.sh"

# Private functions

_query_die() {
    print 'ERROR' "$1" $red
    return 1
}

_query_fail() {
    _query_die "$1" || return 1
}

_require_warm_node() {
    if is_cold_device; then
        _query_fail 'This command can not be run on a cold device'
    fi
}

_require_producer_node() {
    if is_not_producer_device; then
        _query_fail 'This command can only be run on a producer device'
    fi
}

_require_file() {
    if [ ! -f "$1" ]; then
        _query_fail "File $1 does not exist"
    fi
}

_copy_slots_csv_to_grafana() {
    local csvFile="$1"
    local dest=/usr/share/grafana/slots.csv
    [ -d /usr/share/grafana ] || return 0

    if [ -w "$dest" ] || { [ ! -e "$dest" ] && [ -w /usr/share/grafana ]; }; then
        cp "$csvFile" "$dest" || _query_fail 'Could not copy slots CSV to grafana' || return 1
        return 0
    fi

    if sudo -n cp "$csvFile" "$dest" >/dev/null 2>&1; then
        return 0
    fi

    print 'QUERY' "Could not copy $csvFile to $dest without a sudo password. Run once: sudo chown $NODE_USER:grafana $dest && sudo chmod 664 $dest"
    return 0
}

# Public functions

query_tip() {
    _require_warm_node || return 1
    if [ "$1" ]; then
        $CNCLI conway query tip $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH" | jq -r ".$1" | tr -d '\n\r'
    else
        $CNCLI conway query tip $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH"
        echo ''
    fi
    return 0
}

query_params() {
    _require_warm_node || return 1
    $CNCLI conway query protocol-parameters $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH" \
        --out-file "$NETWORK_PATH/params.json" || _query_fail 'Could not query protocol parameters' || return 1
    if [ "$1" ]; then
        cat "$NETWORK_PATH/params.json" | jq -r ".$1" | tr -d '\n\r'
    else
        cat "$NETWORK_PATH/params.json"
        echo ''
    fi
    return 0
}

query_state() {
    _require_warm_node || return 1
    if [ ! -f "$NETWORK_PATH/ledger.json" ]; then
        $CNCLI conway query ledger-state $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH" \
            > "$NETWORK_PATH/ledger.json" || _query_fail 'Could not query ledger state' || return 1
    fi
    if [ "$1" ]; then
        cat "$NETWORK_PATH/ledger.json" | jq -r ".$1" | tr -d '\n\r'
    else
        cat "$NETWORK_PATH/ledger.json"
        echo ''
    fi
    return 0
}

query_metrics() {
    _require_warm_node || return 1
    local metrics_url="http://$(node_metrics_curl_host):${NODE_METRICS_PORT}/metrics"
    if [ "$1" ]; then
        curl -s "$metrics_url" | grep "$1"
    else
        curl -s "$metrics_url"
    fi
    return 0
}

query_config() {
    _require_file "$NETWORK_PATH/$1" || return 1
    cat "$NETWORK_PATH/$1"
    echo ''
    return 0
}

query_key() {
    _require_file "$NETWORK_PATH/keys/$1" || return 1
    cat "$NETWORK_PATH/keys/$1"
    echo ''
    return 0
}

query_keys() {
    local displayType=${1:-table}
    if [[ $displayType == "table" ]]; then
        printf "|%-22s|%-52s|\n" "$(printf '%.0s-' {1..22})" "$(printf '%.0s-' {1..52})"
        printf "| %-20s | %-50s |\n" "Filename" "Contents"
        printf "|%-22s|%-52s|\n" "$(printf '%.0s-' {1..22})" "$(printf '%.0s-' {1..52})"
        for file in $NETWORK_PATH/keys/*; do
            if [[ ! -f "$file" ]]; then
                continue
            fi
            filename=$(basename "$file")
            raw_content=$(<"$file")
            if echo "$raw_content" | jq empty 2>/dev/null; then
                content=$(echo "$raw_content" | jq -c .)
            else
                content=$(head -n 1 "$file" | tr -d '\n')
            fi
            printf "| %-20s | %-50.50s |\n" "$filename" "$content"
        done
        printf "|%-22s|%-52s|\n" "$(printf '%.0s-' {1..22})" "$(printf '%.0s-' {1..52})"
        return 0
    fi

    if stat --version >/dev/null 2>&1; then
        get_modified() { stat -c "%y" "$1" | cut -d'.' -f1; }
        get_perms()  { stat -c "%A" "$1"; }
        get_size()   { stat -c "%s" "$1"; }
    else
        get_modified() { stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$1"; }
        get_perms()  { stat -f "%Sp" "$1"; }
        get_size()   { stat -f "%z" "$1"; }
    fi

    for file in $NETWORK_PATH/keys/*; do
        [ -f "$file" ] || continue

        local filename=$(basename "$file")
        local modified=$(get_modified "$file")
        local perms=$(get_perms "$file")
        local size=$(get_size "$file")
        local content=$(<"$file")
        echo "|==============================================|"
        echo "| 📄 $filename ($size bytes) ($modified)"
        echo "| 🔐 $perms"
        echo "|----------------------------------------------|"
        echo
        if echo "$content" | jq empty 2>/dev/null; then
            echo "$content" | jq
        else
            echo "$content"
        fi
        echo
    done
    return 0
}

query_kes() {
    _require_producer_node || return 1
    _require_file "$NODE_CERT" || return 1
    $CNCLI conway query kes-period-info $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH" \
        --op-cert-file "$NODE_CERT"
    return 0
}

query_kes_period() {
    _require_warm_node || return 1
    _require_file "$NETWORK_PATH/shelley-genesis.json" || return 1
    local slotsPerKESPeriod=$(cat "$NETWORK_PATH/shelley-genesis.json" | jq -r '.slotsPerKESPeriod')
    local slotNo=$(query_tip slot) || return 1
    local kesPeriod=$(($slotNo / $slotsPerKESPeriod))
    echo "slotsPerKESPeriod: $slotsPerKESPeriod"
    echo "currentSlot: $slotNo"
    echo "kesPeriod: $kesPeriod"
    return 0
}

query_uxto() {
    _require_warm_node || return 1
    _require_file "$PAYMENT_ADDR" || return 1
    cardano_cli_query_utxo_text "${1:-"$(cat $PAYMENT_ADDR)"}" /dev/stdout || _query_fail 'Could not query UTXO' || return 1
    return 0
}

query_leader() {
    _require_producer_node || return 1
    _require_file "$POOL_ID" || return 1

    local period="--${1:-"next"}"
    local targetEpoch
    targetEpoch=$(query_tip epoch) || return 1
    if [[ $period != '--next' && $period != '--current' ]]; then
        _query_fail "Leadership schedule incorrect period value: $period" || return 1
    fi
    if [ $period == '--next' ]; then targetEpoch=$(($targetEpoch + 1)); fi

    local outputPath=$NETWORK_PATH/logs
    local tempFilePath=$outputPath/$targetEpoch.txt
    local csvFile=$outputPath/slots.csv
    local poolId=$(<$POOL_ID)

    print 'QUERY' "Leadership schedule starting, please wait..."
    mkdir -p "$outputPath" || _query_fail 'Could not create logs directory' || return 1
    $CNCLI conway query leadership-schedule $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH" \
        --genesis "$NETWORK_PATH/shelley-genesis.json" \
        --stake-pool-id "$poolId" \
        --vrf-signing-key-file "$VRF_KEY" \
        $period >"$tempFilePath" || {
            rm -f "$tempFilePath"
            _query_fail 'Leadership schedule failed to run' || return 1
        }

    if [ ! -f "$csvFile" ]; then
        echo 'Time,Slot,No,Epoch' >"$csvFile" || _query_fail 'Could not create slots CSV file' || return 1
    fi

    if [ ! -s "$tempFilePath" ]; then
        rm -f "$tempFilePath"
        _query_fail 'Leadership schedule failed to run' || return 1
    fi

    local content
    content=$(jq -r --arg epoch "$targetEpoch" '
      to_entries[]
      | .value as $v
      | ($v.slotTime
         | strptime("%Y-%m-%dT%H:%M:%SZ")
         | strftime("%Y-%m-%d %H:%M:%S")) as $dt
      | "\($dt),\($v.slotNumber),\(.key + 1),\($epoch)"
    ' "$tempFilePath") || {
        rm -f "$tempFilePath"
        _query_fail 'Could not parse leadership schedule output' || return 1
    }

    while IFS= read -r line; do
        [ -z "$line" ] && continue
        grep -qxF "$line" "$csvFile" || echo "$line" >>"$csvFile"
    done <<< "$content"

    echo "$content"
    _copy_slots_csv_to_grafana "$csvFile" || return 1
    return 0
}

query_leader_next() {
    _require_producer_node || return 1
    _require_file "$POOL_ID" || return 1
    _require_file "$NETWORK_PATH/shelley-genesis.json" || return 1

    local currentEpoch slotInEpoch epochLength targetEpoch tempFilePath epochPct
    currentEpoch=$(query_tip epoch) || return 1
    targetEpoch=$((currentEpoch + 1))
    tempFilePath=$NETWORK_PATH/logs/$targetEpoch.txt

    if [ -s "$tempFilePath" ] && jq empty "$tempFilePath" 2>/dev/null; then
        print 'QUERY' "Leadership schedule for epoch $targetEpoch already exists at $tempFilePath"
        return 0
    fi

    slotInEpoch=$(query_tip slotInEpoch) || return 1
    epochLength=$(jq -r '.epochLength' "$NETWORK_PATH/shelley-genesis.json")
    if [ -z "$slotInEpoch" ] || [ "$slotInEpoch" = "null" ] || [ -z "$epochLength" ] || [ "$epochLength" = "null" ] || [ "$epochLength" -le 0 ]; then
        _query_fail 'Could not determine epoch progress from the node' || return 1
    fi
    if (( slotInEpoch * 100 < epochLength * 75 )); then
        epochPct=$((slotInEpoch * 100 / epochLength))
        print 'QUERY' "Leadership schedule skipped: epoch $currentEpoch is ${epochPct}% complete (need 75%)"
        return 0
    fi

    query_leader next
}

query_rewards() {
    _require_warm_node || return 1
    _require_file "$STAKE_ADDR" || return 1
    local data
    data=$(
        $CNCLI conway query stake-address-info $NETWORK_ARG --socket-path "$NETWORK_SOCKET_PATH" \
            --address "$(<$STAKE_ADDR)" | jq '.[0]'
    ) || _query_fail 'Could not query stake address info' || return 1
    if [ "$1" ]; then
        echo "$data" | jq -r ".$1"
    else
        echo "$data"
    fi
    return 0
}

case $1 in
    tip) query_tip "${@:2}" ;;
    params) query_params "${@:2}" ;;
    state) query_state "${@:2}" ;;
    metrics) query_metrics "${@:2}" ;;
    config) query_config "${@:2}" ;;
    key) query_key "${@:2}" ;;
    keys) query_keys "${@:2}" ;;
    kes) query_kes ;;
    kes_period) query_kes_period ;;
    uxto) query_uxto "${@:2}" ;;
    leader) query_leader "${@:2}" ;;
    leader_next) query_leader_next ;;
    rewards) query_rewards "${@:2}" ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
