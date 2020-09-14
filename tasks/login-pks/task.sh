#!/usr/bin/env bash

function login_pks() {
	(
		echo "Logging into PKS (${PKS_API_URL})..."
		pks login -a "${PKS_API_URL}" -u "${PKS_USER}" -p "${PKS_PASSWORD}" -k
	)
}

function main() {
	login_pks

	if cluster_exists "${CLUSTER}"; then
		printf "Logging into k8s cluster (%s)..." "${CLUSTER}"
		echo "${PKS_PASSWORD}" | pks get-credentials "${CLUSTER}" > /dev/null 2>&1
	fi

	return 0
}

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__DIR}/../../scripts/helpers.sh" ]] && source "${__DIR}/../../scripts/helpers.sh" ||  \
    echo "No helpers.sh found"

main || exit 1

cp ~/.kube/config kube-config/config

cp ~/.pks/creds.yml pks-config/creds.yml