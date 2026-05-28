#!/bin/bash
# Usage: midnight.sh (
#   query (method <STRING>) (params <STRING>) [id <INT>] |
#   status |
#   validators [epoch <INT>] |
#   validate (type <STRING>) (authorKey <STRING>) |
#   peers |
#   help [-h]
# )
#
# Info:
#
#   - query) Query the API via CURL with the passed method and params JSON array. Returns the raw JSON-RPC response.
#   - status) Query sidechain_getStatus via the Midnight API.
#   - validators) Query sidechain_getAriadneParameters for the passed or current epoch.
#   - validate) Query author_hasKey for the passed type and author key.
#   - peers) Query system_peers via the Midnight API.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../env"
source "$(dirname "$0")/common.sh"

MIDNIGHT_API_HOST="127.0.0.1"
MIDNIGHT_API_PORT="9944"
MIDNIGHT_API_URL="http://${MIDNIGHT_API_HOST}:${MIDNIGHT_API_PORT}"
MIDNIGHT_API_CURL_OPTS=(
  -s
  -S
  -L
  --fail
)

# Private functions

_midnight_die() {
    print 'ERROR' "$1" $red
    return 1
}

_midnight_fail() {
    _midnight_die "$1" || return 1
}

_require_param() {
    if [ -z "${1:-}" ]; then
        _midnight_fail "Parameter ${2:-unknown} is empty"
    fi
}

# Public functions

midnight_query_rpc() {
    _require_param "${1}" "1 method" || return 1
    _require_param "${2}" "2 params" || return 1
    local method="$1"
    local params="$2"
    local id="${3:-1}"
    local payload
    payload=$(cat <<EOF
{
  "jsonrpc": "2.0",
  "method": "${method}",
  "params": ${params},
  "id": ${id}
}
EOF
)
    local response
    if ! response=$(curl "${MIDNIGHT_API_CURL_OPTS[@]}" -X POST -H "Content-Type: application/json" \
        -d "${payload}" "${MIDNIGHT_API_URL}" 2>/dev/null); then
        print_json_error "Failed to reach API at ${MIDNIGHT_API_URL}"
        return 1
    fi

    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "$response"
        return 1
    fi

    echo "$response"
    return 0
}

midnight_query_status() {
    midnight_query_rpc "sidechain_getStatus" "[]" | jq
    return $?
}

midnight_query_validators() {
    local epoch=${1}

    if [[ -z "$epoch" ]]; then
        epoch=$(midnight_query_status | jq -r '.result.mainchain.epoch')
        if [[ -z "$epoch" || "$epoch" == "null" ]]; then
            print_json_error "Unable to determine current epoch"
            return 1
        fi
    fi

    midnight_query_rpc "sidechain_getAriadneParameters" "[$epoch]" | jq
    return $?
}

midnight_query_validate() {
    _require_param "$1" "1 type" || return 1
    _require_param "$2" "2 author key" || return 1
    midnight_query_rpc "author_hasKey" "[\"$2\",\"$1\"]" | jq
    return $?
}

midnight_query_peers() {
    midnight_query_rpc "system_peers" "[]" | jq
    return $?
}

case $1 in
    query) midnight_query_rpc "${@:2}" ;;
    status) midnight_query_status ;;
    validators) midnight_query_validators "${@:2}" ;;
    validate) midnight_query_validate "${@:2}" ;;
    peers) midnight_query_peers ;;
    help) help "${2:-"--help"}" ;;
    *) help "${1:-"--help"}" ;;
esac
exit $?
