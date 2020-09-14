#!/usr/bin/env bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

PKS_API="${1:-$PKS_API}"
PKS_USER="${2:-$PKS_USER}"
PKS_PASSWORD="${3:-$PKS_PASSWORD}"
CLUSTER="${4:-$CLUSTER}"
CLUSTER_DOMAIN="${5:-$CLUSTER_DOMAIN}"
NAMESPACE="${6:-$NAMESPACE}"
CLUSTER_CERT="${7:-$CLUSTER_CERT}"
UAA_PORT="${8:-$UAA_PORT}"

if [[ -z "${PKS_API}" ]]; then
    "echo PKS_API var not set"
    exit 1
fi

if [[ -z "${PKS_USER}" ]]; then
    "echo PKS_USER var not set"
    exit 1
fi

if [[ -z "${PKS_PASSWORD}" ]]; then
    "echo PKS_PASSWORD var not set"
    exit 1
fi

if [[ -z "${CLUSTER}" ]]; then
    "echo CLUSTER var not set"
    exit 1
fi

if [[ -z "${CLUSTER_DOMAIN}" ]]; then
    echo "CLUSTER_DOMAIN var not set"
    exit 1
fi

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__DIR}/../../scripts/helpers.sh" ]] && source "${__DIR}/../../scripts/helpers.sh" ||  \
    echo "No helpers.sh found"

login_pks_k8s_cluster "${PKS_API}" "${PKS_USER}" "${PKS_PASSWORD}" "${CLUSTER}" "${CLUSTER_DOMAIN}" "${NAMESPACE}" "${CLUSTER_CERT}"
