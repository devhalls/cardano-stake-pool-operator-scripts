#!/bin/bash

# Define global variables

source_from="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$source_from/.." && pwd)"
source "$source_from/../env"

CONFIG_SOURCE="$REPO_ROOT/configs/node/$NODE_VERSION/$NODE_NETWORK"
SERVICES_SOURCE="${SERVICES_SOURCE:-$REPO_ROOT/configs/services}"
SCHEMA_SOURCE="${SCHEMA_SOURCE:-$REPO_ROOT/configs/schema}"

NETWORK_ARG=
case $NODE_NETWORK in
    "mainnet") NETWORK_ARG="--mainnet" ;;
    "preprod") NETWORK_ARG="--testnet-magic 1" ;;
    "preview") NETWORK_ARG="--testnet-magic 2" ;;
    "sanchonet") NETWORK_ARG="--testnet-magic 4" ;;
esac

CONFIG_PATH=
case $NODE_TYPE in
    "relay") CONFIG_PATH=$NETWORK_PATH/config.json ;;
    "producer") CONFIG_PATH=$NETWORK_PATH/config-bp.json ;;
esac

CONFIG_DOWNLOADS=(
    "config.json"
    "db-sync-config.json"
    "submit-api-config.json"
    "topology.json"
    "peer-snapshot.json"
    "byron-genesis.json"
    "shelley-genesis.json"
    "alonzo-genesis.json"
    "conway-genesis.json"
    "guardrails-script.plutus"
)
case $NODE_NETWORK in
    "mainnet")
        CONFIG_DOWNLOADS+=("checkpoints.json" "topology-non-bootstrap-peers.json" "config-bp.json")
        ;;
    "preview")
        CONFIG_DOWNLOADS+=("checkpoints.json")
        ;;
    "sanchonet")
        CONFIG_DOWNLOADS+=("dijkstra-genesis.json" "config-bp.json")
        ;;
esac

GUILD_SCRIPT_DOWNLOADS=(
    "gLiveView.sh"
    "env"
)

MITHRIL_AGGREGATOR_ENDPOINT=
case $NODE_NETWORK in
    "mainnet") MITHRIL_AGGREGATOR_ENDPOINT=https://aggregator.release-mainnet.api.mithril.network/aggregator ;;
    "preprod") MITHRIL_AGGREGATOR_ENDPOINT=https://aggregator.release-preprod.api.mithril.network/aggregator ;;
    "preview") MITHRIL_AGGREGATOR_ENDPOINT=https://aggregator.pre-release-preview.api.mithril.network/aggregator ;;
esac

if [[ $NODE_TYPE == 'cold' && $NODE_NETWORK == 'mainnet' ]]; then
    MITHRIL_AGGREGATOR_PARAMS=''
else
    MITHRIL_AGGREGATOR_PARAMS=
        case $NODE_NETWORK in
            "mainnet") MITHRIL_AGGREGATOR_PARAMS=$(jq -nc --arg address $(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/era.addr) --arg verification_key $(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-mainnet/era.vkey) '{"address": $address, "verification_key": $verification_key}') ;;
            "preprod") MITHRIL_AGGREGATOR_PARAMS=$(jq -nc --arg address $(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/era.addr) --arg verification_key $(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/release-preprod/era.vkey) '{"address": $address, "verification_key": $verification_key}') ;;
            "preview") MITHRIL_AGGREGATOR_PARAMS=$(jq -nc --arg address $(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/era.addr) --arg verification_key $(wget -q -O - https://raw.githubusercontent.com/input-output-hk/mithril/main/mithril-infra/configuration/pre-release-preview/era.vkey) '{"address": $address, "verification_key": $verification_key}') ;;
        esac
fi

GOV_ACTION_TYPES=(
    "motion_no_confidence"
    "committee_update"
    "constitution_update"
    "hard_fork_initiation"
    "parameter_change"
    "treasury_withdrawal"
    "info"
)

# Define global colours

blue='\033[0;34m'
orange='\033[0;33m'
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'

# Define global functions

help() {
    echo -e $orange
    sed -ne '/^#/!q;s/^#$/# /;/^# /s/^# //p' <"$0" |
        awk -v f="${1#-h}" '!f && /^Usage:/ || u { u=!/^\s*$/; if (!u) exit } u || f'
    echo -e $nc
    exit 1
}

print() {
    label=${1:-'LABEL'}
    message=${2:-'Message'}
    color=${3:-$orange}
    echo -e "$color[$label] $message$nc"
    if [ -f "$NETWORK_PATH/logs/script.log" ]; then
        echo -e "$color[$label] $message$nc" >>$NETWORK_PATH/logs/script.log
    fi
}

print_state() {
    local state="$1"
    local message="$2"

    if [ -n "$state" ]; then
        echo -e "$green+++$nc | $message"
    else
        echo -e "$red---$nc | $message"
    fi
}

print_service_state() {
    local service="$1"
    local title="${2:-$service}"
    local status=$(systemctl is-active $service 2>/dev/null)

    # Should this service be enabled for the selected NODE_NETWORK / NODE_TYPE combination
    local required
    case "$NODE_NETWORK:$NODE_TYPE:$service" in
        *":"*":$NETWORK_SERVICE" | *":"*":$PROMETHEUS_EXPORTER_SERVICE")
            required="required" ;;
        *) required="-" ;;
    esac

    # Print the result
    if [ "$status" = "active" ]; then
        print_state "${status}" "${title} | ${green}${service} IS running${nc} | ${green}${required}${nc}"
    else
        print_state "" "${title} | ${red}${service} is NOT running${nc} | ${red}${required}${nc}"
    fi
}

print_crontab_state() {
    local cronTab="$1"
    local title="${2:-'Cron tab'}"

    # Should this cron be enabled for the selected NODE_NETWORK / NODE_TYPE combination
    local required
    case "$NODE_NETWORK:$NODE_TYPE:$cronTab" in
        *":"*":$NODE_HOME/scripts/pool.sh get_stats")
            required="required" ;;
        *":producer:$NODE_HOME/scripts/query.sh leader_next")
            required="required" ;;
        *) required="-" ;;
    esac

    if crontab -l 2>/dev/null | grep -Fq "$cronTab"; then
        print_state "active" "$title | ${green}${cronTab} IS installed${nc} | ${green}${required}${nc}"
    else
      print_state "" "$title | ${red}${cronTab} is NOT installed${nc} | ${red}${required}${nc}"
    fi
}

table_strip_ansi() {
    printf '%s' "$1" | sed $'s/\033\\[[0-9;]*[mK]//g'
}

table_trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

table_visible_len() {
    local clean
    clean="$(table_strip_ansi "$1")"
    printf '%s' "${#clean}"
}

# Terminal width for wrapping. Override with PRINT_TABLE_MAX_WIDTH.
table_term_width() {
    local w="${PRINT_TABLE_MAX_WIDTH:-}"
    case "$w" in
        '' | *[!0-9]*) ;;
        *) [ "$w" -gt 0 ] && echo "$w" && return ;;
    esac
    w="${COLUMNS:-}"
    case "$w" in
        '' | *[!0-9]*) ;;
        *) [ "$w" -gt 0 ] && echo "$w" && return ;;
    esac
    w="$(tput cols 2>/dev/null)" || w=""
    case "$w" in
        '' | *[!0-9]*) ;;
        *) [ "$w" -gt 0 ] && echo "$w" && return ;;
    esac
    echo 80
}

# Make a cell safe as a print_table field (`|` is the column delimiter).
table_sanitize_cell() {
    local s="$1"
    s="${s//$'\n'/ }"
    s="${s//|/;}"
    printf '%s' "$s"
}

# Hard-wrap to `width` visible columns. ANSI sequences are not counted and
# active color is carried onto the next line so a split path stays colored.
_table_hard_wrap() {
    local s="$1"
    local width="$2"
    local i=0
    local n=${#s}
    local visible=0
    local buf=""
    local active=""
    local ch seq

    [ "$width" -lt 1 ] && width=1

    while [ "$i" -lt "$n" ]; do
        ch="${s:i:1}"
        if [ "$ch" = $'\033' ]; then
            seq="$ch"
            i=$((i + 1))
            while [ "$i" -lt "$n" ]; do
                ch="${s:i:1}"
                seq="${seq}${ch}"
                i=$((i + 1))
                case "$ch" in
                    [A-Za-z]) break ;;
                esac
            done
            buf="${buf}${seq}"
            case "$seq" in
                *m)
                    case "$seq" in
                        *$'\033[0m' | *$'\033[m') active="" ;;
                        *) active="$seq" ;;
                    esac
                    ;;
            esac
            continue
        fi
        buf="${buf}${ch}"
        visible=$((visible + 1))
        i=$((i + 1))
        if [ "$visible" -ge "$width" ]; then
            if [ -n "$active" ]; then
                printf '%s%s\n' "$buf" "$nc"
                buf="$active"
            else
                printf '%s\n' "$buf"
                buf=""
            fi
            visible=0
        fi
    done
    if [ "$visible" -gt 0 ]; then
        printf '%s\n' "$buf"
    fi
}

# Last punctuation index in the first `width` visible chars (for path-friendly wrap).
_table_last_break() {
    local s="$1"
    local width="$2"
    local i=0
    local n=${#s}
    local visible=0
    local last_slash=-1
    local last_other=-1
    local ch

    while [ "$i" -lt "$n" ] && [ "$visible" -lt "$width" ]; do
        ch="${s:i:1}"
        if [ "$ch" = $'\033' ]; then
            i=$((i + 1))
            while [ "$i" -lt "$n" ]; do
                ch="${s:i:1}"
                i=$((i + 1))
                case "$ch" in
                    [A-Za-z]) break ;;
                esac
            done
            continue
        fi
        visible=$((visible + 1))
        if [ "$i" -gt 0 ]; then
            case "$ch" in
                /) last_slash=$i ;;
                - | _ | = | : | ';' | ,) last_other=$i ;;
            esac
        fi
        i=$((i + 1))
    done
    if [ "$last_slash" -gt 0 ]; then
        printf '%s' "$last_slash"
    else
        printf '%s' "$last_other"
    fi
}

# Split an oversize token at punctuation, else hard-wrap.
_table_split_long_word() {
    local word="$1"
    local width="$2"
    local break_at prefix rest

    while [ "$(table_visible_len "$word")" -gt "$width" ]; do
        break_at="$(_table_last_break "$word" "$width")"
        if [ "$break_at" -gt 0 ]; then
            prefix="${word:0:$((break_at + 1))}"
            rest="${word:$((break_at + 1))}"
            if [ -n "$rest" ]; then
                printf '%s\n' "$prefix"
                word="$rest"
                continue
            fi
        fi
        _table_hard_wrap "$word" "$width"
        return
    done
    [ -n "$word" ] && printf '%s\n' "$word"
}

# Word-wrap a cell to `width` visible columns; oversize tokens wrap at punctuation.
table_wrap_cell() {
    local text="$1"
    local width="$2"
    local line word current vis_word vis_cur
    local -a words

    [ -z "$width" ] && width=1
    [ "$width" -lt 1 ] && width=1

    if [ -z "$text" ]; then
        printf '\n'
        return
    fi

    while IFS= read -r line || [ -n "$line" ]; do
        current=""
        if [ -z "$line" ]; then
            printf '\n'
            continue
        fi
        IFS=' ' read -ra words <<< "$line"
        for word in "${words[@]}"; do
            vis_word="$(table_visible_len "$word")"
            if [ -z "$current" ]; then
                if [ "$vis_word" -gt "$width" ]; then
                    _table_split_long_word "$word" "$width"
                else
                    current="$word"
                fi
            else
                vis_cur="$(table_visible_len "${current} ${word}")"
                if [ "$vis_cur" -le "$width" ]; then
                    current="${current} ${word}"
                else
                    printf '%s\n' "$current"
                    if [ "$vis_word" -gt "$width" ]; then
                        _table_split_long_word "$word" "$width"
                        current=""
                    else
                        current="$word"
                    fi
                fi
            fi
        done
        if [ -n "$current" ]; then
            printf '%s\n' "$current"
        fi
    done <<< "$text"
}

# Header row matching node.sh: "+ - | COL | COL"
table_header() {
    local body=""
    local part
    for part in "$@"; do
        body+=" | $(table_sanitize_cell "$part")"
    done
    echo -e "${green}+${nc} ${red}-${nc}${body}"
}

# Status row: pass (+++), fail (---), or skip (~~~). Remaining args are columns.
table_status_row() {
    local state="$1"
    shift
    local body=""
    local part
    for part in "$@"; do
        [ -n "$body" ] && body+=" | "
        body+="$(table_sanitize_cell "$part")"
    done
    case "$state" in
        skip)
            echo -e "${orange}~~~${nc} | ${body}"
            ;;
        "")
            print_state "" "$body"
            ;;
        *)
            print_state "ok" "$body"
            ;;
    esac
}

# Box-drawn table. Rows are `|`-separated (print_state / table_status_row).
# Long cells wrap so the table fits the terminal; last columns shrink first.
print_table() {
    local lines=("$@")
    local -a col_widths
    local -a cols
    local max_cols=0
    local i line clean len val color_len pad_width
    local min_width=3

    [ ${#lines[@]} -eq 0 ] && return 0

    for line in "${lines[@]}"; do
        line="${line#"${line%%[![:space:]]*}"}"
        IFS='|' read -ra cols <<< "$line"
        (( ${#cols[@]} > max_cols )) && max_cols=${#cols[@]}

        for ((i = 0; i < ${#cols[@]}; i++)); do
            clean="$(table_trim "$(table_strip_ansi "${cols[i]}")")"
            len=${#clean}
            if [ -z "${col_widths[i]:-}" ] || [ "$len" -gt "${col_widths[i]}" ]; then
                col_widths[i]=$len
            fi
        done
    done

    [ "$max_cols" -eq 0 ] && return 0

    for ((i = 0; i < max_cols; i++)); do
        col_widths[i]="${col_widths[i]:-0}"
    done

    local overhead=$((3 * max_cols + 1))
    local usable
    usable="$(table_term_width)"
    [ "$usable" -lt 20 ] && usable=20
    local budget=$((usable - overhead))
    local min_budget=$((max_cols * min_width))
    [ "$budget" -lt "$min_budget" ] && budget=$min_budget

    local sum=0
    for ((i = 0; i < max_cols; i++)); do
        sum=$((sum + col_widths[i]))
    done
    local excess=$((sum - budget))
    i=$((max_cols - 1))
    while [ "$excess" -gt 0 ] && [ "$i" -ge 0 ]; do
        local reducible=$((col_widths[i] - min_width))
        if [ "$reducible" -gt 0 ]; then
            if [ "$reducible" -gt "$excess" ]; then
                col_widths[i]=$((col_widths[i] - excess))
                excess=0
            else
                col_widths[i]=$min_width
                excess=$((excess - reducible))
            fi
        fi
        i=$((i - 1))
    done

    draw_border() {
        printf "+"
        local width
        for width in "${col_widths[@]}"; do
            printf "%s+" "$(printf '%*s' $((width + 2)) '' | tr ' ' '-')"
        done
        echo
    }

    draw_border
    local -a wrapped
    local row_height j piece wrapped_text this_h idx
    for line in "${lines[@]}"; do
        line="${line#"${line%%[![:space:]]*}"}"
        IFS='|' read -ra cols <<< "$line"
        wrapped=()
        row_height=1
        for ((i = 0; i < max_cols; i++)); do
            val="$(table_trim "${cols[i]:-}")"
            wrapped_text="$(table_wrap_cell "$val" "${col_widths[i]}")"
            wrapped_text="${wrapped_text%$'\n'}"
            wrapped[i]="$wrapped_text"
            this_h=0
            while IFS= read -r piece || [ -n "$piece" ]; do
                this_h=$((this_h + 1))
            done <<< "$wrapped_text"
            [ "$this_h" -gt "$row_height" ] && row_height=$this_h
        done

        for ((j = 0; j < row_height; j++)); do
            printf "|"
            for ((i = 0; i < max_cols; i++)); do
                piece=""
                idx=0
                while IFS= read -r val || [ -n "$val" ]; do
                    if [ "$idx" -eq "$j" ]; then
                        piece="$val"
                        break
                    fi
                    idx=$((idx + 1))
                done <<< "${wrapped[i]}"
                clean="$(table_strip_ansi "$piece")"
                color_len=$((${#piece} - ${#clean}))
                pad_width=$((col_widths[i] + color_len))
                printf " %-*s |" "$pad_width" "$piece"
            done
            echo
        done
        draw_border
    done
}

print_json_error() {
    local msg="$1"
    echo "{ \"error\": \"${msg//\"/\\\"}\" }"
}

confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) echo "yes" ;;
        *) exit 1 ;;
    esac
}

platform() {
    OS=$(uname)
    if [[ "$OS" == "Linux" ]]; then
        echo "linux"
    elif [[ "$OS" == "Darwin" ]]; then
        echo "macos"
    elif [[ "$OS" == "MINGW"* || "$OS" == "CYGWIN"* ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

platform_arch() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64 | amd64) echo "amd64" ;;
        arm64 | aarch64 | arm*) echo "arm64" ;;
        *) echo "unknown" ;;
    esac
}

platform_arm() {
    if [[ "$(platform_arch)" == "arm64" ]]; then
        echo "arm"
    fi
}

version_ge() {
    [[ "$(printf '%s\n' "$1" "$2" | sort -V | head -1)" == "$2" ]]
}

# Cardano CLI output helpers (plain-text and JSON formats vary across CLI versions)

cardano_cli_version() {
    local binary="${1:-$CNCLI}"
    $binary --version 2>/dev/null | awk 'NR==1 {print $2; exit}'
}

cardano_node_version() {
    local binary="${1:-$CNNODE}"
    $binary --version 2>/dev/null | awk 'NR==1 {print $2; exit}'
}

parse_cardano_cli_min_fee() {
    local output="$1"
    if echo "$output" | jq -e 'type == "object"' >/dev/null 2>&1; then
        echo "$output" | jq -r '.fee // .'
    else
        echo "$output" | tr -d '\n\r' | awk '{print $1}'
    fi
}

cardano_cli_first_utxo() {
    local address="$1"
    local utxo_json
    utxo_json=$($CNCLI conway query utxo --address "$address" $NETWORK_ARG \
        --socket-path "$NETWORK_SOCKET_PATH" --output-json 2>/dev/null) || return 1
    echo "$utxo_json" | jq -r 'if type == "object" then (keys[0] // empty) else empty end'
}

cardano_cli_query_utxo_text() {
    local address="$1"
    local output_file="$2"
    $CNCLI conway query utxo --output-text $NETWORK_ARG \
        --socket-path "$NETWORK_SOCKET_PATH" \
        --address "$address" >"$output_file"
}

cardano_cli_utxo_text_balances() {
    local utxo_file="$1"
    local balance_file="$2"
    tail -n +3 "$utxo_file" | sort -k3 -nr >"$balance_file"
}

cardano_cli_utxo_text_field() {
    local line="$1"
    local field="$2"
    case "$field" in
        txHash) awk '{ print $1 }' <<<"$line" ;;
        txIx) awk '{ print $2 }' <<<"$line" ;;
        lovelace) awk '{ print $3 }' <<<"$line" ;;
        datumType) awk '{ print $6 }' <<<"$line" ;;
    esac
}

cardano_cli_utxo_line_spendable() {
    [[ "$(cardano_cli_utxo_text_field "$1" datumType)" == 'TxOutDatumNone' ]]
}

require_cardano_node_arm64_version() {
    if [[ "$(platform_arch)" == "arm64" ]] && ! version_ge "$NODE_VERSION" "10.6.2"; then
        print 'ERROR' "Node version $NODE_VERSION has no arm64 release. Set NODE_VERSION to 10.6.2 or later." $red
        exit 1
    fi
}

node_metrics_curl_host() {
    case "${NODE_METRICS_HOST}" in
        0.0.0.0 | '[::]' | ::) echo '127.0.0.1' ;;
        *) echo "${NODE_METRICS_HOST}" ;;
    esac
}

require_dbsync_arm64_support() {
    if [[ "$(platform)" == "linux" && "$(platform_arch)" == "arm64" ]]; then
        print 'ERROR' "cardano-db-sync does not publish linux-arm64 release binaries from IntersectMBO." $red
        exit 1
    fi
}

# cardano-node source build: lib versions from node tag flake.lock → iohk-nix flake.lock
cardano_build_iohk_nix_rev() {
    local node_ver="${1:-$NODE_VERSION}"
    curl -sf "https://raw.githubusercontent.com/IntersectMBO/cardano-node/${node_ver}/flake.lock" \
        | jq -r '.nodes.iohkNix.locked.rev'
}

cardano_build_lib_versions_from_node() {
    local node_ver="${1:-$NODE_VERSION}"
    local iohk_flake

    IOHKNIX_VERSION="$(cardano_build_iohk_nix_rev "$node_ver")" || return 1
    if [ -z "$IOHKNIX_VERSION" ] || [ "$IOHKNIX_VERSION" = "null" ]; then
        return 1
    fi

    iohk_flake="$(curl -sf "https://raw.githubusercontent.com/input-output-hk/iohk-nix/${IOHKNIX_VERSION}/flake.lock")" || return 1
    SODIUM_VERSION="$(echo "$iohk_flake" | jq -r '.nodes.sodium.original.rev')"
    SECP256K1_VERSION="$(echo "$iohk_flake" | jq -r '.nodes.secp256k1.original.ref')"
    BLST_VERSION="$(echo "$iohk_flake" | jq -r '.nodes.blst.original.ref')"

    if [ -z "$SODIUM_VERSION" ] || [ "$SODIUM_VERSION" = "null" ]; then
        return 1
    fi
    if [ -z "$SECP256K1_VERSION" ] || [ "$SECP256K1_VERSION" = "null" ]; then
        return 1
    fi
    if [ -z "$BLST_VERSION" ] || [ "$BLST_VERSION" = "null" ]; then
        return 1
    fi
    return 0
}

cardano_node_release_filenames() {
    local version="$NODE_VERSION"
    local os=$(platform)
    local arch=$(platform_arch)

    case "$os" in
        windows)
            echo "cardano-node-${version}-win-amd64.zip"
            echo "cardano-node-${version}-win64.zip"
            ;;
        macos)
            echo "cardano-node-${version}-macos-${arch}.tar.gz"
            if [[ "$arch" == "amd64" ]]; then
                echo "cardano-node-${version}-macos.tar.gz"
            fi
            ;;
        linux)
            echo "cardano-node-${version}-linux-${arch}.tar.gz"
            if [[ "$arch" == "amd64" ]]; then
                echo "cardano-node-${version}-linux.tar.gz"
            fi
            ;;
        *)
            print 'ERROR' "Unsupported platform: $os" $red
            return 1
            ;;
    esac
}

mithril_release_filenames() {
    local version="$MITHRIL_VERSION"
    local os=$(platform)
    local arch=$(platform_arch)
    local suffix="x64"
    if [[ "$arch" == "arm64" ]]; then
        suffix="arm64"
    fi

    case "$os" in
        windows) echo "mithril-${version}-windows-x64.tar.gz" ;;
        macos)
            echo "mithril-${version}-macos-${suffix}.tar.gz"
            if [[ "$arch" == "amd64" ]]; then
                echo "mithril-${version}-macos-x64.tar.gz"
            fi
            ;;
        linux) echo "mithril-${version}-linux-${suffix}.tar.gz" ;;
        *)
            print 'ERROR' "Unsupported platform: $os" $red
            return 1
            ;;
    esac
}

dbsync_release_filenames() {
    local version="$DB_SYNC_VERSION"
    local os=$(platform)
    local arch=$(platform_arch)

    case "$os" in
        linux)
            if [[ "$arch" == "amd64" ]]; then
                echo "cardano-db-sync-${version}-linux.tar.gz"
            fi
            echo "cardano-db-sync-${version}-linux-${arch}.tar.gz"
            ;;
        macos)
            echo "cardano-db-sync-${version}-macos-${arch}.tar.gz"
            echo "cardano-db-sync-${version}-macos.tar.gz"
            ;;
        windows)
            print 'ERROR' "cardano-db-sync windows binaries are not published by IntersectMBO" $red
            return 1
            ;;
        *)
            print 'ERROR' "Unsupported platform: $os" $red
            return 1
            ;;
    esac
}

remove_path() {
    [ $# -gt 0 ] || return 0
    command rm -rf "$@"
}

download_release_file() {
    local remote="$1"
    shift
    local filename url

    DOWNLOAD_RELEASE_FILENAME=
    mkdir -p downloads
    for filename in "$@"; do
        url="$remote/$filename"
        print 'DOWNLOAD' "Trying $url" >&2
        wget -O "downloads/$filename" "$url"
        if [ $? -eq 0 ]; then
            DOWNLOAD_RELEASE_FILENAME="$filename"
            return 0
        fi
        remove_path "downloads/$filename"
    done
    return 1
}

platform_ctl() {
    if [ -f /.dockerenv ]; then
        return 1
    else
        return 0
    fi
}

get_param() {
    echo "$1" | grep "^$2" | awk '{for(i=2; i<=NF; i++) printf "%s ", $i; print ""}'
}

get_option() {
    local option_name="$1"
    local option_value=""
    shift
    while [[ $# -gt 1 ]]; do
        case "$1" in
            "$option_name")
                option_value="$option_value $2"
                shift 2 # move past the option and its value
                ;;
            *)
                shift # unknown option
                ;;
        esac
    done
    echo "$option_value"
}

update_or_append() {
    local file="$1"
    local check="$2"
    local line="$3"
    if grep -q "^${check}" "$file"; then
        sed -i "s|^${check}.*|${line}|" "$file"
    else
        echo "$line" | tee -a "$file" > /dev/null
    fi
}

exit_if_file_missing() {
    if [ ! -f $1 ]; then
        print 'ERROR' "File $1 does not exist" $red
        exit 1
    fi
}

exit_if_empty() {
    if [ -z "${1:-}" ]; then
        print 'ERROR' "Parameter ${2:-unknown} is empty" $red
        exit 1
    fi
}

# Guard predicates return 0 when the restriction applies.
# Prefer these with script-local _fail helpers during script refactors.

is_cold_device() {
    [[ $NODE_TYPE == 'cold' && $NODE_NETWORK == 'mainnet' ]]
}

is_not_cold_device() {
    [[ $NODE_TYPE != 'cold' && $NODE_NETWORK == 'mainnet' ]]
}

is_not_producer_device() {
    [[ $NODE_TYPE != 'producer' && $NODE_NETWORK == 'mainnet' ]]
}

is_not_relay_device() {
    [[ $NODE_TYPE != 'relay' && $NODE_NETWORK == 'mainnet' ]]
}

# Guard exits (legacy - prefer predicates with script-local fail helpers)

exit_if_cold() {
    if is_cold_device; then
        print 'ERROR' 'This command can not be run on a cold device' $red
        exit 1
    fi
}

exit_if_not_cold() {
    if is_not_cold_device; then
        print 'ERROR' 'This command can only be run on a cold device' $red
        exit 1
    fi
}

exit_if_not_producer() {
    if is_not_producer_device; then
        print 'ERROR' 'This command can only be run on a producer device' $red
        exit 1
    fi
}

exit_if_not_relay() {
    if is_not_relay_device; then
        print 'ERROR' 'This command can only be run on a relay device' $red
        exit 1
    fi
}
