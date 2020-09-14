#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

function main() {
    local rootdir="${1}"
    local delete_flag="${2:-false}"
    clusters=(./config-repo/*)

	##
	## Stash the list of live clusters into an array for referencing later
	##
	k8s_clusters=$(pks clusters --json | jq -r 'sort_by(.name) | .[] | .name')

	## This first loop is the "create" section
    for d in "${clusters[@]}"; do
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
        if cluster_exists "${cluster}"; then
            echo
            printf "cluster '%s' already exists" "${cluster}"
            continue
        fi
        echo

        ##
        ## Drop down into cluster directory
        ##
        cd "$d"

        ## Create cluster
        args=("")
        name=$(om interpolate --config ./cluster-info.yml --path /name > /dev/null 2>&1 || echo "")
        if [[ -n "${name}" ]]; then
            cluster="${name}"
        fi
        plan=$(om interpolate --config ./cluster-info.yml --path /plan)
        if [[ -z "${plan}" ]]; then
            echo "Argument 'plan' is required to create cluster"
            exit 1
        fi
        args+=("--plan ${plan}")
        nodes=$(om interpolate --config ./cluster-info.yml --path /num-nodes)
        if [[ -z "${nodes}" ]]; then
            echo "Argument 'num-nodes' is required to create cluster"
            exit 1
        fi
        args+=("--num-nodes ${nodes}")
        external_hostname=$(om interpolate --config ./cluster-info.yml --path /external-hostname)
        if [[ -z "${external_hostname}" ]]; then
            echo "Argument 'external-hostname' is required to create cluster"
            exit 1
        fi
        args+=("--external-hostname ${external_hostname}")
        network_profile=$(om interpolate --config ./cluster-info.yml --path /network-profile > /dev/null 2>&1 || echo "")
        if [[ -n "${network_profile}" ]]; then
            args+=("--network-profile ${network_profile}")
        fi

        pks create-cluster "${cluster}" ${args[@]}
        echo ""
        echo "Waiting for cluster '$cluster' with -external-hostname '$external_hostname' to be created"
        success=false
        until ${success}; do
            set +e
            status=$(pks cluster "$cluster" --json | jq -r '.last_action_state')
            if [ "$status" = "succeeded" ]; then
                success=true
            fi
            if [ "$status" = "failed" ]; then
                echo "Failed to create $cluster"
                exit 1
            fi
            set -e
            printf '.'
            sleep 5
        done
        echo "Created $cluster successfully"
		cd - > /dev/null 2>&1
    done

    cd "$rootdir/config-repo"

	##
	## This second loop is the "delete" section
	##
	for cluster in ${k8s_clusters[*]}; do

		##
		## The protected-clusters.yml file contains namespaces which are required to be in existence, so make sure
		## not to delete those
		##
		protected=$(om interpolate --config ./protected-clusters.yml --path /protected_clusters | grep "${cluster}" | cut -d' ' -f2) || echo ""

		if [[ ${protected} == "${cluster}"  ]]; then
			echo "${cluster} is a protected cluster. skipping delete"
			echo ""
			continue
		fi

		##
		## Otherwise, remove the namespace (which will automatically remove any namespace-scoe resources,
		## e.g.: pods, deployments, virtualservices, etc.)
		##
		if [[ ! -d "${cluster}"  ]]; then
			echo "Deleting cluster ${cluster}..."
			pks delete-cluster "${cluster}" --non-interactive
			echo ""
		fi
	done

}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__DIR}/../../scripts/helpers.sh" ]] && source "${__DIR}/../../scripts/helpers.sh" ||  \
    echo "No helpers.sh found"

mkdir -p ~/.pks
cp pks-config/creds.yml ~/.pks/creds.yml

delete_flag="${1:-$DELETE_FLAG}"
rootdir=$PWD

main "$rootdir" "$delete_flag"
