#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

function main() {
    clusters=(./config-repo/*)

	## This first loop is the "create" section
    for d in "${clusters[@]}"; do
        ##
        ## Text files cannot be cluster... so let's skip those
        ##
        if [[ ! -d "$d" ]]; then
            continue
        fi

        ##
        ## Drop down into cluster directory
        ##
        cd "$d"

        ## Check if there are any network profiles
        if [[ ! $(om interpolate --config ./cluster-info.yml --path /network-profiles 2>/dev/null | grep file | awk '{print $NF}') ]]; then
            printf "No network profiles exist for cluster %s" "$d"
            continue
        fi

        ## Create network profiles
        network_profiles=( "$(om interpolate --config ./cluster-info.yml --path /network-profiles 2>/dev/null | grep file | awk '{print $NF}')" )
        for network_profile in ${network_profiles[@]}; do
            echo "Creating network profile: '${network_profile}'"
	        cat "$PWD/${network_profile}"
            pks create-network-profile "$PWD/${network_profile}"
        done
    done
}

__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__DIR}/../../scripts/helpers.sh" ]] && source "${__DIR}/../../scripts/helpers.sh" ||  \
    echo "No helpers.sh found"

mkdir -p ~/.pks
cp pks-config/creds.yml ~/.pks/creds.yml

main
