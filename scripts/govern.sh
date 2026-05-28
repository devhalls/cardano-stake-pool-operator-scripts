#!/bin/bash
# Usage: govern.sh (
#   action (govActionId <STRING>) |
#   vote (govActionId <STRING>) (govActionIndex <INT>) (decision <STRING>) [anchorUrl <STRING>] [anchorHash <STRING>] [keyFile <STRING<'node'|'drep'|'cc'>>] |
#   hash (anchorUrl <STRING>) |
#   id_CIP129 [type <STRING<'drep1'|'drep_script1'|'cc_hot1'|'cc_hot_script1'|'cc_cold1'|'cc_cold_script1'>>] |
#   drep_id [format <STRING<'--output-bech32'|'--output-hex'>>] |
#   drep_state |
#   drep_keys |
#   drep_cert (url <STRING>) [deposit <BOOLEAN>] |
#   drep_dreg_cert |
#   cc_cold_keys |
#   cc_cold_hash |
#   cc_hot_keys |
#   cc_hot_hash |
#   cc_cert |
#   help [-h]
# )
#
# Info:
#
#   - action) Query the blockchain for a gov action info by its tx ID. Expects a govActionId param.
#   - vote) Cast a vote for the passed params, keyFile defaults to 'node' assuming a pool vote. Can be 'node' | 'drep' | 'cc'.
#   - hash) Hash a CIP108 file from its anchor URL, to use when you vote.
#   - id_CIP129) Retrieve CIP129 for DRep or cc hot / cold keys.
#   - drep_id) Retrieve the DReps id. Optionally pass the format '--output-bech32'|'--output-hex', defaults to bech32.
#   - drep_state) Retrieve your DRep state.
#   - drep_keys) Generate DRep keys.
#   - drep_cert) Generate DRep certificate expecting the passed url for the drep metadata json. Optionally pass second param to update-certificate.
#   - drep_dreg_cert) Generate DRep de-registration certificate ($DREP_DREG_CERT).
#   - cc_cold_keys) Generate CC cold keys.
#   - cc_cold_hash) Generate CC cold hash.
#   - cc_hot_keys) Generate CC hot keys.
#   - cc_hot_hash) Generate CC hot hash.
#   - cc_cert) Generate CC certificate.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/common.sh"

# Private functions

_govern_die() {
    print 'ERROR' "$1" $red
    return 1
}

_govern_fail() {
    _govern_die "$1" || return 1
}

_require_warm_node() {
    if is_cold_device; then
        _govern_fail 'This command can not be run on a cold device'
    fi
}

_require_cold_node() {
    if is_not_cold_device; then
        _govern_fail 'This command can only be run on a cold device'
    fi
}

_require_producer_node() {
    if is_not_producer_device; then
        _govern_fail 'This command can only be run on a producer device'
    fi
}

_require_param() {
    if [ -z "${1:-}" ]; then
        _govern_fail "Parameter ${2:-unknown} is empty"
    fi
}

_require_file() {
    if [ ! -f "$1" ]; then
        _govern_fail "File $1 does not exist"
    fi
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _govern_fail 'Operation cancelled' ;;
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

govern_action() {
    _require_warm_node || return 1
    _require_param "${1}" "1 govActionId" || return 1
    local govActionId=${1}
    echo $govActionId
    $CNCLI conway query gov-state $NETWORK_ARG --socket-path $NETWORK_SOCKET_PATH |
        jq -r --arg govActionId "$govActionId" '.proposals | to_entries[] | select(.value.actionId.txId | contains($govActionId)) | .value'
    return $?
}

govern_vote() {
    _require_cold_node || return 1
    _require_param "${1}" "1 govActionId" || return 1
    _require_param "${2}" "2 govActionIndex" || return 1
    _require_param "${3}" "3 decision" || return 1
    local govActionId=${1}
    local govActionIndex=${2}
    local decision=${3}
    local anchor=${4}
    local anchorHash=${5}
    local keyFile=${6:-'node'}
    local outputPath=$NETWORK_PATH/temp/vote.raw
    local anchorArg
    if [ "$decision" != "yes" ] && [ "$decision" != "no" ] && [ "$decision" != "abstain" ]; then
        _govern_fail "Incorrect decision value $decision: allowed values 'yes' | 'no' | 'abstain'" || return 1
    fi

    if [[ -n "$anchor" ]]; then
        anchorArg="--anchor-url $anchor --anchor-data-hash $anchorHash"
    fi

    local verificationArg=
    case $keyFile in
        "node") verificationArg="--cold-verification-key-file $NODE_VKEY" ;;
        "drep") verificationArg="--drep-verification-key-file $DREP_VKEY" ;;
        "cc") verificationArg="--cc-hot-verification-key-file $CC_HOT_VKEY" ;;
        *) _govern_fail "Incorrect keyFile value $keyFile: allowed values 'node' | 'drep' | 'cc'" || return 1 ;;
    esac

    $CNCLI conway governance vote create \
        --$decision \
        --governance-action-tx-id "$govActionId" \
        --governance-action-index "$govActionIndex" \
        $verificationArg \
        $anchorArg \
        --out-file $outputPath || _govern_fail 'Could not create vote' || return 1

    print 'GOVERN' "Vote created for $keyFile. Voted: $decision. Output: $outputPath" $green
    return 0
}

govern_hash() {
    _require_warm_node || return 1
    _require_param "${1}" "1 anchor url" || return 1
    local outputFileJson="$NETWORK_PATH/temp/anchor.json"
    local outputFileHash="$NETWORK_PATH/temp/anchor.txt"
    wget -O $outputFileJson ${1} || _govern_fail 'Could not download anchor metadata' || return 1
    _require_file "$outputFileJson" || return 1

    $CNCLI hash anchor-data \
         --file-text "${outputFileJson}" >"${outputFileHash}" || _govern_fail 'Could not hash anchor metadata' || return 1

    rm $outputFileJson
    print 'GOVERN' "Anchor metadata hash created at $outputFileHash" $green
    return 0
}

govern_id_CIP129() {
    _require_producer_node || return 1
    local type=${1:-drep1}
    local hexId=$($CNBECH32 <<< "$(govern_drep_id)")
    local formatted
    case "${type}" in
        "drep1"*) formatted=$($CNBECH32 "drep" <<< "22${hexId}") ;;
        "drep_script1"*) formatted=$($CNBECH32 "drep" <<< "23${hexId}") ;;
        "cc_hot1"*) formatted=$($CNBECH32 "cc_hot" <<< "02${hexId}") ;;
        "cc_hot_script1"*) formatted=$($CNBECH32 "cc_hot" <<< "03${hexId}") ;;
        "cc_cold1"*) formatted=$($CNBECH32 "cc_cold" <<< "12${hexId}") ;;
        "cc_cold_script1"*) formatted=$($CNBECH32 "cc_cold" <<< "13${hexId}") ;;
        *) _govern_fail "Unable to convert ${type}" || return 1 ;;
    esac
    echo "${formatted}"
    return 0
}

govern_drep_id() {
    _require_producer_node || return 1
    local format="${1:-"--output-bech32"}"
    $CNCLI conway governance drep id \
        --drep-verification-key-file $DREP_VKEY \
        $format \
        --out-file $DREP_ID || _govern_fail 'Could not retrieve DRep id' || return 1
    cat $DREP_ID
    return 0
}

govern_drep_state() {
    _require_warm_node || return 1
    _require_file "$DREP_VKEY" || return 1
    $CNCLI conway query drep-state \
        --drep-key-hash "$(govern_drep_id --output-hex)" \
        $NETWORK_ARG \
        --socket-path $NETWORK_SOCKET_PATH
    return $?
}

govern_generate_drep_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$DREP_VKEY" "DRep keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway governance drep key-gen \
        --verification-key-file $DREP_VKEY \
        --signing-key-file $DREP_KEY || _govern_fail 'Could not generate DRep keys' || return 1
    print 'GOVERN' "DRep keys created at $NETWORK_PATH/keys" $green
    return 0
}

govern_generate_drep_cert() {
    _require_cold_node || return 1
    _require_file "$DREP_VKEY" || return 1
    _require_file "$NODE_HOME/metadata/drep.json" || return 1
    _require_file_missing_or_confirm "$DREP_CERT" "DRep certificate already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    local url=${1}
    local update=${2}
    local file=$NODE_HOME/metadata/drep.json
    local hash=$($CNCLI conway governance drep metadata-hash --drep-metadata-file $file)
    print "GOVERN" "DRep metadata URL: $url"
    print "GOVERN" "DRep metadata hash: $hash"

    if [ -z "$update" ]; then
        deposit=${2:-$($CNCLI conway query protocol-parameters $NETWORK_ARG --socket-path $NETWORK_SOCKET_PATH | jq .dRepDeposit)}
        print "GOVERN" "DRep deposit: $deposit"
        $CNCLI conway governance drep registration-certificate \
            --drep-verification-key-file $DREP_VKEY \
            --key-reg-deposit-amt $deposit \
            --drep-metadata-url $url \
            --drep-metadata-hash $hash \
            --out-file $DREP_CERT || _govern_fail 'Could not generate DRep registration certificate' || return 1
    else
        $CNCLI conway governance drep update-certificate \
            --drep-verification-key-file $DREP_VKEY \
            --drep-metadata-url $url \
            --drep-metadata-hash $hash \
            --out-file $DREP_CERT || _govern_fail 'Could not generate DRep update certificate' || return 1
    fi

    print 'GOVERN' "DRep certificate created at $DREP_CERT" $green
    return 0
}

govern_generate_drep_dreg_cert() {
    _require_cold_node || return 1
    _require_file "$DREP_VKEY" || return 1
    _require_file_missing_or_confirm "$DREP_DREG_CERT" "DRep de-registration certificate already exists! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway governance drep unregistration-certificate \
        --drep-verification-key-file $DREP_VKEY \
        --out-file $DREP_DREG_CERT || _govern_fail 'Could not generate DRep de-registration certificate' || return 1
    print 'GOVERN' "DRep de-registration certificate created at $DREP_DREG_CERT" $green
    return 0
}

govern_generate_cc_cold_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$CC_COLD_KEY" "CC cold keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway governance committee key-gen-cold \
      --cold-verification-key-file $CC_COLD_VKEY \
      --cold-signing-key-file $CC_COLD_KEY || _govern_fail 'Could not generate CC cold keys' || return 1
    print 'GOVERN' "CC cold keys created at $NETWORK_PATH/keys" $green
    return 0
}

govern_generate_cc_cold_hash() {
    _require_cold_node || return 1
    _require_file "$CC_COLD_VKEY" || return 1
    $CNCLI conway governance committee key-hash \
      --verification-key-file $CC_COLD_VKEY > $CC_COLD_HASH || _govern_fail 'Could not generate CC cold hash' || return 1
    print 'GOVERN' "CC cold hash created at $NETWORK_PATH/keys" $green
    return 0
}

govern_generate_cc_hot_keys() {
    _require_cold_node || return 1
    _require_file_missing_or_confirm "$CC_HOT_KEY" "CC hot keys already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway governance committee key-gen-hot \
      --verification-key-file $CC_HOT_VKEY \
      --signing-key-file $CC_HOT_KEY || _govern_fail 'Could not generate CC hot keys' || return 1
    print 'GOVERN' "CC hot keys created at $NETWORK_PATH/keys" $green
    return 0
}

govern_generate_cc_hot_hash() {
    _require_cold_node || return 1
    _require_file "$CC_HOT_VKEY" || return 1
    $CNCLI conway governance committee key-hash \
      --verification-key-file $CC_HOT_VKEY > $CC_HOT_HASH || _govern_fail 'Could not generate CC hot hash' || return 1
    print 'GOVERN' "CC hot hash created at $NETWORK_PATH/keys" $green
    return 0
}

govern_generate_cc_cert() {
    _require_cold_node || return 1
    _require_file "$CC_COLD_VKEY" || return 1
    _require_file "$CC_HOT_VKEY" || return 1
    _require_file_missing_or_confirm "$CC_CERT" "CC certificate already exist! 'yes' to overwrite, 'no' to cancel" || return 1
    $CNCLI conway governance committee create-hot-key-authorization-certificate \
      --cold-verification-key-file $CC_COLD_VKEY \
      --hot-verification-key-file $CC_HOT_VKEY \
      --out-file $CC_CERT || _govern_fail 'Could not generate CC certificate' || return 1
    print 'GOVERN' "CC certificate created at $CC_CERT" $green
    return 0
}

case $1 in
    action) govern_action "${@:2}" ;;
    vote) govern_vote "${@:2}" ;;
    hash) govern_hash "${@:2}" ;;
    id_CIP129) govern_id_CIP129 "${@:2}" ;;
    drep_id) govern_drep_id "${@:2}" ;;
    drep_state) govern_drep_state ;;
    drep_keys) govern_generate_drep_keys ;;
    drep_cert) govern_generate_drep_cert "${@:2}" ;;
    drep_dreg_cert) govern_generate_drep_dreg_cert ;;
    cc_cold_keys) govern_generate_cc_cold_keys ;;
    cc_cold_hash) govern_generate_cc_cold_hash ;;
    cc_hot_keys) govern_generate_cc_hot_keys ;;
    cc_hot_hash) govern_generate_cc_hot_hash ;;
    cc_cert) govern_generate_cc_cert ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
