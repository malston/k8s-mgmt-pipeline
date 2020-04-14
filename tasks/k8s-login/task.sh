#!/usr/bin/env bash

function login_pks_k8s_cluster() {
	local cluster="${1}"
	local password="${2}"

	printf "Logging into k8s cluster (%s)..." "${cluster}"
	echo "${password}" | pks get-credentials "${cluster}" > /dev/null 2>&1

	return 0
}

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

cluster="${1:-$CLUSTER}"
admin_password="${2:-$ADMIN_PASSWORD}"

if [[ -z "${cluster}" ]]; then
  echo "Cluster name is required"
  exit 1
fi

if [[ -z "${admin_password}" ]]; then
  echo "PKS admin password is required"
  exit 1
fi

login_pks_k8s_cluster "$cluster" "$admin_password" || exit 1

cp ~/.kube/config kube-config/config
