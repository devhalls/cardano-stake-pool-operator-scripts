#!/bin/bash
# Usage: test.sh (
#   smoke |
#   integration |
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
#   - all) Run smoke, then integration.
#   - list) List registered tests per suite.
#   - report) Run all suites and update docs/TESTS.md results section.
#   - help) View this file's help.

source "$(dirname "$0")/common.sh"
source "$(dirname "$0")/test/lib.sh"
source "$(dirname "$0")/test/validate-env.sh"
source "$(dirname "$0")/test/validate-services.sh"
source "$(dirname "$0")/test/validate-configs.sh"
source "$(dirname "$0")/test/validate-build.sh"
source "$(dirname "$0")/test/smoke.sh"
source "$(dirname "$0")/test/integration.sh"

TEST_SUITE=""
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
                echo "ERROR: test.sh fixture is disabled; use ./docker/fixture.sh for setup flows" >&2
                exit 1
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
        exit 0
        ;;
    help | -h | --help)
        help "${TEST_ARGS[0]:-"--help"}"
        ;;
    *)
        help "${TEST_SUITE:-"--help"}"
        ;;
esac
