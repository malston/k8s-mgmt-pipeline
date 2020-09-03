#!/bin/bash +x

set -o errexit
set -o errtrace
set -o pipefail

function login_pks_k8s_cluster() {
    local api="${1}"
    local user="${2}"
    local password="${3}"
    local cluster="${4}"
    local cluster_domain="${5}"
    local namespace="${6}"
    local ca_cert="${7}"

    cmd="./login-k8s.sh --api=${api} --cluster=${cluster} --domain=${cluster_domain} --user=${user} --password=\"${password}\""

    if [[ -n ${namespace} ]]; then
        cmd+=" --namespace ${namespace}"
    fi

    if [[ -n ${ca_cert} ]]; then
        cmd+=" --ca-cert ${ca_cert}"
    fi

    eval "${cmd}"
    result=$?

    mkdir -p kube-config
    cp "$HOME/.kube/config" kube-config/config

    return "$result"
}

function cluster_exists() {
    local cluster="${1}"

    pks cluster "${cluster}" > /dev/null 2>&1

    return $?
}