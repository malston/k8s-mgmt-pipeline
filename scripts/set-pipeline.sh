#!/usr/bin/env bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

TARGET="${1:?"Must supply a target for fly"}"

fly -t "$TARGET" sp -p k8s-mgmt -c pipeline.yml -l creds.yml -l pipeline-params.yml