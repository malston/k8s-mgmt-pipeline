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
    ## Start by applying the ClusterRole and ClusterRoleBinding, if it exists
    ##
    if [[ -f clusterrole.yml ]]; then
      echo "Apply ClusterRole on cluster ${cluster}..."
      kubectl apply -f clusterrole.yml
      echo
    fi
    
    if [[ -f cluster-rolebinding.yml ]]; then
      echo "Apply ClusterRoleBinding on cluster ${cluster}..."
      kubectl apply -f cluster-rolebinding.yml
      echo
    fi

    ##
    ## Use find to get the list of directories - wheere each directory is to be a namespace inside
    ## this cluster
    ##
    for config_namespace in $(find . -mindepth 1 -maxdepth 1 -not -path '*/\.*' -type d | cut -d"/" -f2); do
      ##
      ## Now apply the things...
      ##
      if [[ -f ${config_namespace}/role.yml ]]; then
        echo "Apply Role in namespace ${config_namespace}..."
        kubectl apply -f "${config_namespace}/role.yml" -n "${config_namespace}"
      fi

      if [[ -f ${config_namespace}/rolebinding.yml ]]; then
        echo "Apply RoleBinding to roles in namespace ${config_namespace}..."
        kubectl apply -f "${config_namespace}/rolebinding.yml" -n "${config_namespace}"
      fi

      if [[ -f ${config_namespace}/cluster-rolebinding.yml ]]; then
        echo "Apply ClusterRoleBinding in namespace ${config_namespace}..."
        kubectl apply -f "${config_namespace}/cluster-rolebinding.yml" -n "${config_namespace}"
      fi
    done
    echo
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