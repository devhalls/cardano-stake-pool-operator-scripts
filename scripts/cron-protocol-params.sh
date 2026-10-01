#!/bin/bash
# Refresh Conway protocol parameters JSON for Cardano Connect API (and local ops).
#
# Writes: $NETWORK_PATH/params.json (same as scripts/query.sh params)
#
# Crontab example (node host, warm relay/producer — run before API rsync, e.g. :10):
#   10 * * * * /home/upstream/Cardano/scripts/cron-protocol-params.sh >> /home/upstream/Cardano/cardano-node/logs/crontab.log 2>&1
#
# See docs/deployment/09-cardano-connect-protocol-params.md

set -euo pipefail

source "$(dirname "$0")/common.sh"

if is_cold_device; then
    print 'CRON' 'protocol-params skipped on cold device' $orange
    exit 0
fi

log_dir="$NETWORK_PATH/logs"
mkdir -p "$log_dir"

if ! "$REPO_ROOT/scripts/query.sh" params stakePoolTargetNum >/dev/null; then
    print 'CRON' 'protocol-params query failed' $red
    exit 1
fi

if [ ! -s "$NETWORK_PATH/params.json" ]; then
    print 'CRON' "params.json missing after query ($NETWORK_PATH/params.json)" $red
    exit 1
fi

print 'CRON' "protocol-params updated at $NETWORK_PATH/params.json" $green
exit 0
