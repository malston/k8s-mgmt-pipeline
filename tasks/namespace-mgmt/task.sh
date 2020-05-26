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
    local password="${1}"
    local delete_flag="${2:-false}"
    
    ##
    ## "config-repo" is the foundation-specific configuration repo; each directory in there is
    ## to be a cluster on that namespace
    ##
    for d in ./config-repo/*; do
        cluster=${d#"./config-repo/"}
        
        ##
        ## Text files cannot be cluster... so let's skip those
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
        
        ## This first loop is the "create" section
        
        ##
        ## Stash the list of live namespaces into an array for referencing later
        ##
        k8s_namespaces=( "$(kubectl get namespaces -o json | jq -r '.items[].metadata.name')" )
        
        ##
        ## Use find to get the list of directories - where each directory is to be a namespace inside
        ## this cluster
        ##
        for config_namespace in $(find . -mindepth 1 -maxdepth 1 -not -path '*/\.*' -type d | cut -d"/" -f2); do
            
            ##
            ## Get the list of namespaces in this cluster and then check to ensure there is a matching
            ## directory. If the directory exists AND the namespace is already there, echo a helpful
            ## message and continue on
            ##
            if [[ "${k8s_namespaces[*]} " =~ ${config_namespace} ]]; then
                echo "${config_namespace} already exists. skipping creation"
                echo ""
                continue
            fi
            
            ##
            ## Conversely, if the namespace wasn't found, it gets created here
            ##
            if [[ ! "${k8s_namespaces[*]} " =~ ${config_namespace} ]]; then
                echo "creating namespace ${config_namespace}"
                kubectl create ns "${config_namespace}"
                kubectl label ns "${config_namespace}" "name=${config_namespace}"
                echo ""
            fi
        done
        
        ##
        ## Don't delete namespaces unless explicitly specified
        ##
        if [[ $delete_flag = false ]]; then
            continue
        fi
        
        ##
        ## This second loop is the "delete" section
        ##
        for ns in ${k8s_namespaces[*]}; do
            
            ##
            ## The protected-ns.yml file contains namespaces which are required to be in existence, so make sure
            ## not to delete those
            ##
            protected=$(bosh int ./protected-ns.yml --path /protected_ns | grep "${ns}" | cut -d' ' -f2) || echo ""
            
            if [[ ${protected} == "${ns}"  ]]; then
                echo "${ns} is a protected namespace. skipping delete"
                echo ""
                continue
            fi
            
            ##
            ## Otherwise, remove the namespace (which will automatically remove any namespace-scoe resources,
            ## e.g.: pods, deployments, virtualservices, etc.)
            ##
            if [[ ! -d ${ns}  ]]; then
                echo "Deleting namespace ${ns} from cluster ${cluster}..."
                kubectl delete ns "${ns}"
                echo ""
            fi
        done
        cd - > /dev/null 2>&1
    done
}

password="${1:-$PKS_PASSWORD}"
delete_flag="${2:-$DELETE_FLAG}"

if [[ -z "${password}" ]]; then
    echo "PKS admin password is required"
    exit 1
fi

mkdir -p ~/.pks
cp pks-config/creds.yml ~/.pks/creds.yml

mkdir -p ~/.kube
cp kube-config/config ~/.kube/config

main "$password" "$delete_flag"