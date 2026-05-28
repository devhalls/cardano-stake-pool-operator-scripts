#!/bin/bash
set -e
env="$(dirname "$0")/../env.docker"
config="$(dirname "$0")/docker-compose.yaml"
source $env
exec_flags=-i
if [ -t 1 ] && [ -z "${CI:-}" ]; then
    exec_flags=-it
fi
docker exec --env-file $env $exec_flags node $NODE_HOME/scripts/"$@"
