#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

function login_pks_k8s_cluster() {
	local cluster="${1}"
	local password="${2}"

	printf "Logging into k8s cluster (%s)..." "${cluster}"
	echo "${password}" | pks get-credentials "${cluster}" > /dev/null 2>&1

	return $?
}

function main() {

  ##
  ## "config-repo" is the foundation-specific configuration repo; each directory in there is
  ## to be a cluster on that namespace
  ##
  for d in ./config-repo/*; do
    cluster=${d#"./config-repo/"}
    ##
    ## Text files cannot be clusters... so let's skip those
    ##
    if [[ ! -d "$d" ]]; then
      continue
    fi

    ##
    ## Set the directory name to be the cluster we need to login to, and do the login
    ##
    if ! login_pks_k8s_cluster "${cluster}" "${password}"; then
      echo
      echo "cluster does not exist"
      continue
    fi
    echo
    
    ##
    ## Drop down into cluster directory
    ##
    cd "$d"

    ## 
    ## Apply a default quota, if it exists
    ##
    if [[ -f default-quotas.yml ]]; then
      echo "Apply default quota to cluster ${cluster}..."
      kubectl apply -f default-quotas.yml
      echo
    fi
    
    ## 
    ## Apply default limits, if exists
    ##
    if [[ -f default-limits.yml ]]; then
      echo "Apply default limits to cluster ${cluster}..."
      kubectl apply -f default-limits.yml
      echo
    fi

  done
}

password="${1:-$PKS_PASSWORD}"

if [[ -z "${password}" ]]; then
  echo "PKS admin password is required"
  exit 1
fi

mkdir -p ~/.pks
cp pks-config/creds.yml ~/.pks/creds.yml

mkdir -p ~/.kube
cp kube-config/config ~/.kube/config


main "$password"