#!/bin/bash
# Usage: test.sh (
#   smoke |
#   integration |
#   fixture [subcommand] |
#   all |
#   list |
#   report |
#   help [-h]
# ) [--report] [--verbose] [--release <VERSION>]
#
# Info:
#
#   - smoke) Non-chain smoke tests (env, configs, help, binaries).
#   - integration) Read-only chain queries (requires node socket).
#   - fixture) Destructive fixture-parity flows; optional subcommand (address, spo_register, ...).
#   - all) Run smoke, then integration, then fixture.
#   - list) List registered tests per suite.
#   - report) Run all suites and update docs/TESTS.md results section.
#   - help) View this file's help.

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/test/lib.sh"
source "$(dirname "$0")/test/validate-env.sh"
source "$(dirname "$0")/test/validate-services.sh"
source "$(dirname "$0")/test/smoke.sh"
source "$(dirname "$0")/test/integration.sh"
source "$(dirname "$0")/test/fixture.sh"

TEST_SUITE=""
TEST_FIXTURE_SUB=""
TEST_ARGS=()

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --report) TEST_REPORT=1 ;;
            --verbose) TEST_VERBOSE=1 ;;
            --release)
                shift
                TEST_ENV_RELEASE="${1:-}"
                [ -z "$TEST_ENV_RELEASE" ] && echo "ERROR: --release requires a version" >&2 && exit 1
                ;;
            smoke | integration | all | list | report)
                TEST_SUITE="$1"
                ;;
            fixture)
                TEST_SUITE="fixture"
                shift
                if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
                    TEST_FIXTURE_SUB="$1"
                    shift
                fi
                TEST_ARGS=("$@")
                return 0
                ;;
            help | -h | --help)
                TEST_SUITE="help"
                shift
                TEST_ARGS=("$@")
                return 0
                ;;
        esac
        shift
    done
    [ -z "$TEST_SUITE" ] && TEST_SUITE="help"
}

run_suite_all() {
    test_reset_counters

    print 'TEST' 'Running suite: smoke' $blue
    echo ""
    run_suite_smoke

    print 'TEST' 'Running suite: integration' $blue
    echo ""
    run_suite_integration

    print 'TEST' 'Running suite: fixture' $blue
    echo ""
    run_suite_fixture
}

parse_args "$@"

case "$TEST_SUITE" in
    smoke)
        test_reset_counters
        run_suite_smoke
        test_print_summary smoke
        code=$?
        [ "$TEST_REPORT" -eq 1 ] && test_write_report smoke
        exit $code
        ;;
    integration)
        test_reset_counters
        run_suite_integration
        test_print_summary integration
        code=$?
        [ "$TEST_REPORT" -eq 1 ] && test_write_report integration
        exit $code
        ;;
    fixture)
        test_reset_counters
        run_suite_fixture "$TEST_FIXTURE_SUB" "${TEST_ARGS[@]}"
        test_print_summary "fixture ${TEST_FIXTURE_SUB:-all}"
        code=$?
        [ "$TEST_REPORT" -eq 1 ] && test_write_report "fixture ${TEST_FIXTURE_SUB:-all}"
        exit $code
        ;;
    all)
        run_suite_all
        test_print_summary all
        code=$?
        [ "$TEST_REPORT" -eq 1 ] && test_write_report all
        exit $code
        ;;
    report)
        run_suite_all
        test_print_summary all
        code=$?
        test_write_report all || code=1
        exit $code
        ;;
    list)
        list_suite_smoke
        echo ""
        list_suite_integration
        echo ""
        list_suite_fixture
        exit 0
        ;;
    help | -h | --help)
        help "${TEST_ARGS[0]:-"--help"}"
        ;;
    *)
        help "${TEST_SUITE:-"--help"}"
        ;;
esac
