#!/bin/bash
# Test harness library — sourced by scripts/test.sh and suite modules.

TEST_PASSED=0
TEST_FAILED=0
TEST_SKIPPED=0
TEST_VERBOSE="${TEST_VERBOSE:-0}"
TEST_REPORT="${TEST_REPORT:-0}"

TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR:-$(mktemp -d)}"
TEST_LAST_CAPTURE=""
TEST_FAILURE_LOG=""
TEST_RUN_LINES=""

TEST_SCRIPTS_DIR="${TEST_SCRIPTS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
TEST_REPO_ROOT="${TEST_REPO_ROOT:-$REPO_ROOT}"

# Resolve docs/TESTS.md (host repo root or $NODE_HOME/docs when mounted in Docker)
test_resolve_docs_file() {
    local root docs_dir
    for root in "$TEST_REPO_ROOT" "$(cd "$TEST_SCRIPTS_DIR/.." && pwd)"; do
        [ -n "$root" ] || continue
        docs_dir="$root/docs"
        if [ -f "$docs_dir/TESTS.md" ] || [ -d "$docs_dir" ]; then
            echo "$docs_dir/TESTS.md"
            return 0
        fi
    done
    return 1
}

TEST_DOCS_FILE="${TEST_DOCS_FILE:-$(test_resolve_docs_file 2>/dev/null || echo "$TEST_REPO_ROOT/docs/TESTS.md")}"

if [ -f /.dockerenv ]; then
    TEST_IN_DOCKER=1
else
    TEST_IN_DOCKER=0
fi

# --- script invocation ---

run_script() {
    local script="$1"
    shift
    bash "$TEST_SCRIPTS_DIR/$script" "$@"
}

capture_script() {
    local script="$1"
    shift
    local capture_file
    capture_file="$(mktemp)"
    if run_script "$script" "$@" >"$capture_file" 2>&1; then
        TEST_LAST_CAPTURE="$(cat "$capture_file")"
        rm -f "$capture_file"
        return 0
    else
        local code=$?
        TEST_LAST_CAPTURE="$(cat "$capture_file")"
        rm -f "$capture_file"
        return $code
    fi
}

# --- assertions ---

assert_nonempty() {
    local value="$1"
    local message="${2:-expected non-empty value}"
    if [ -z "$value" ]; then
        echo "$message"
        return 1
    fi
    return 0
}

assert_matches() {
    local value="$1"
    local pattern="$2"
    local message="${3:-value does not match pattern}"
    if ! echo "$value" | grep -qE "$pattern"; then
        echo "$message (got: $value)"
        return 1
    fi
    return 0
}

assert_file_exists() {
    local file="$1"
    local message="${2:-file does not exist: $file}"
    if [ ! -f "$file" ]; then
        echo "$message"
        return 1
    fi
    return 0
}

assert_help() {
    local script="$1"
    local out
    local code=0
    out="$(run_script "$script" help 2>&1)" || code=$?
    if [ "$code" -ne 1 ]; then
        echo "help for $script expected exit 1, got $code"
        return 1
    fi
    if ! echo "$out" | grep -q 'Usage:'; then
        echo "help for $script missing Usage: block"
        return 1
    fi
    return 0
}

# --- prerequisites (skip, do not fail) ---

require_socket() {
    if [ ! -S "$NETWORK_SOCKET_PATH" ]; then
        return 1
    fi
    return 0
}

require_keys_dir() {
    if [ ! -d "$NETWORK_PATH/keys" ]; then
        return 1
    fi
    return 0
}

require_payment_keys() {
    require_keys_dir || return 1
    assert_file_exists "$PAYMENT_KEY" >/dev/null 2>&1 || return 1
    assert_file_exists "$STAKE_KEY" >/dev/null 2>&1 || return 1
    return 0
}

require_payment_address() {
    require_payment_keys || return 1
    assert_file_exists "$PAYMENT_ADDR" >/dev/null 2>&1 || return 1
    return 0
}

require_keys_missing() {
    if [ -f "$PAYMENT_KEY" ] || [ -f "$STAKE_KEY" ]; then
        return 1
    fi
    return 0
}

require_funded_wallet() {
    require_payment_address || return 1
    local utxo
    utxo="$(capture_script query.sh uxto 2>/dev/null)" || return 1
    if [ -z "$utxo" ] || echo "$utxo" | grep -qi 'no utxos\|empty'; then
        return 1
    fi
    return 0
}

require_drep_keys() {
    assert_file_exists "$DREP_KEY" >/dev/null 2>&1 || return 1
    return 0
}

require_producer_node() {
    [ "$NODE_TYPE" = "producer" ]
}

require_network_config() {
    assert_file_exists "$NETWORK_PATH/$1" >/dev/null 2>&1 || return 1
    return 0
}

# --- runner ---

skip_test() {
    local name="$1"
    local reason="$2"
    TEST_SKIPPED=$((TEST_SKIPPED + 1))
    echo -e "${orange}SKIP${nc} | $name | $reason"
    TEST_RUN_LINES+="SKIP | $name | $reason"$'\n'
}

run_test() {
    local name="$1"
    local fn="$2"
    shift 2

    echo -e "${blue}RUN${nc} | $name"

    local capture_file
    capture_file="$(mktemp)"
    local code=0

    if ! declare -f "$fn" >/dev/null; then
        code=1
        echo "test function $fn not found" >"$capture_file"
    else
        "$fn" "$@" >"$capture_file" 2>&1
        code=$?
    fi

    local output
    output="$(cat "$capture_file")"
    rm -f "$capture_file"

    if [ "$code" -eq 2 ]; then
        local reason="${output%%$'\n'*}"
        [ -z "$reason" ] && reason="skipped"
        skip_test "$name" "$reason"
        return 0
    fi

    if [ "$code" -eq 0 ]; then
        TEST_PASSED=$((TEST_PASSED + 1))
        print_state "pass" "$name"
        TEST_RUN_LINES+="PASS | $name"$'\n'
        if [ "$TEST_VERBOSE" -eq 1 ] && [ -n "$output" ]; then
            echo "$output" | sed 's/^/  /'
        fi
        return 0
    fi

    TEST_FAILED=$((TEST_FAILED + 1))
    print_state "" "$name"
    TEST_RUN_LINES+="FAIL | $name"$'\n'
    echo -e "${red}FAILURE OUTPUT:${nc}"
    echo "$output" | sed 's/^/  /'
    TEST_FAILURE_LOG+="=== $name ==="$'\n'"$output"$'\n\n'
    return 1
}

test_print_summary() {
    local suite="${1:-all}"
    echo ""
    print 'TEST' "Suite: $suite" $blue
    print 'TEST' "Passed: $TEST_PASSED | Failed: $TEST_FAILED | Skipped: $TEST_SKIPPED" $orange
    if [ "$TEST_FAILED" -gt 0 ]; then
        print 'TEST' 'One or more tests failed' $red
        return 1
    fi
    print 'TEST' 'All tests passed' $green
    return 0
}

test_reset_counters() {
    TEST_PASSED=0
    TEST_FAILED=0
    TEST_SKIPPED=0
    TEST_FAILURE_LOG=""
    TEST_RUN_LINES=""
}

test_environment_label() {
    local label="local"
    if [ "$TEST_IN_DOCKER" -eq 1 ]; then
        label="docker"
    fi
    echo "${label} | network=${NODE_NETWORK:-unknown} | type=${NODE_TYPE:-unknown}"
}

test_write_report() {
    local suite="${1:-all}"
    local docs_file docs_dir

    if ! docs_file="$(test_resolve_docs_file)"; then
        print 'TEST' "Docs path not available inside this environment" $red
        echo "  Expected: \$REPO_ROOT/docs/TESTS.md (e.g. /home/ubuntu/Cardano/docs/TESTS.md in Docker)"
        echo "  Recreate the node container so docs/ is mounted: ./docker/run.sh up -d"
        echo "  Or run --report from the host repo: ./scripts/test.sh $suite --report"
        return 1
    fi

    docs_dir="$(dirname "$docs_file")"
    if [ ! -d "$docs_dir" ]; then
        print 'TEST' "Docs directory missing: $docs_dir" $red
        echo "  Recreate the node container: ./docker/run.sh up -d"
        return 1
    fi

    if [ ! -f "$docs_file" ]; then
        print 'TEST' "Creating $docs_file (docs dir is mounted but TESTS.md was missing)" $orange
        printf '%s\n' '# Tests' '' '> Auto-created shell; run report again after merging with docs/TESTS.md from the repo.' '' >>"$docs_file"
    fi

    TEST_DOCS_FILE="$docs_file"

    local git_sha=""
    if command -v git >/dev/null 2>&1 && [ -d "$TEST_REPO_ROOT/.git" ]; then
        git_sha="$(git -C "$TEST_REPO_ROOT" rev-parse --short HEAD 2>/dev/null || true)"
    fi

    local timestamp
    timestamp="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    local env_label
    env_label="$(test_environment_label)"

    local block
    block=$(cat <<EOF
<!-- TEST_RESULTS_START -->
## Last run

- **Time:** $timestamp
- **Git:** ${git_sha:-n/a}
- **Environment:** $env_label
- **Suite:** $suite
- **Summary:** passed=$TEST_PASSED failed=$TEST_FAILED skipped=$TEST_SKIPPED

### Results

\`\`\`
$(echo -n "$TEST_RUN_LINES")
\`\`\`
EOF
)

    if [ -n "$TEST_FAILURE_LOG" ]; then
        block+=$'\n\n### Failure details\n\n```\n'"$TEST_FAILURE_LOG"$'\n```\n'
    fi

    block+=$'\n<!-- TEST_RESULTS_END -->'

    local tmp
    tmp="$(mktemp)"
    if grep -q 'TEST_RESULTS_START' "$docs_file"; then
        awk '
            /<!-- TEST_RESULTS_START -->/ { inblock=1; next }
            /<!-- TEST_RESULTS_END -->/ { inblock=0; next }
            inblock { next }
            { print }
        ' "$docs_file" >"$tmp"
        echo "$block" >>"$tmp"
        mv "$tmp" "$docs_file"
    else
        echo "" >>"$docs_file"
        echo "$block" >>"$docs_file"
    fi

    print 'TEST' "Updated $docs_file" $green
    return 0
}
