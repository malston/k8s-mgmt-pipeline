#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

function main() {
    local api="${1}"
    local user="${2}"
    local password="${3}"
    local cluster="${4}"
    local cluster_domain="${5}"
    local namespace="${6}"
    local ca_cert="${7}"

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
    if ! login_pks_k8s_cluster "${api}" "${user}" "${password}" "${cluster}" "${cluster_domain}" "${namespace}" "${ca_cert}"; then
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

PKS_API="${1:-$PKS_API}"
PKS_USER="${2:-$PKS_USER}"
PKS_PASSWORD="${3:-$PKS_PASSWORD}"
CLUSTER="${4:-$CLUSTER}"
CLUSTER_DOMAIN="${5:-$CLUSTER_DOMAIN}"
NAMESPACE="${6:-$NAMESPACE}"
CLUSTER_CERT="${7:-$CLUSTER_CERT}"

if [[ -z "${PKS_API}" ]]; then
    echo "PKS_API var not set"
    exit 1
fi

if [[ -z "${PKS_USER}" ]]; then
    echo "PKS_USER var not set"
    exit 1
fi

if [[ -z "${PKS_PASSWORD}" ]]; then
    echo "PKS_PASSWORD var not set"
    exit 1
fi

if [[ -z "${CLUSTER}" ]]; then
    echo "CLUSTER var not set"
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

main "${PKS_API}" "${PKS_USER}" "${PKS_PASSWORD}" "${CLUSTER}" "${CLUSTER_DOMAIN}" "${NAMESPACE}" "${CLUSTER_CERT}"
