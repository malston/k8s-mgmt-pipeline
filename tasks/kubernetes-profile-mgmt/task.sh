#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

function main() {
    local rootdir="${1}"
    local delete_flag="${2:-false}"
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

        ## Create kubernetes profile
        kubernetes_profiles=$(om interpolate --config ./cluster-info.yml --path /kubernetes-profiles 2>/dev/null | grep file | awk '{print $NF}')
        for kubernetes_profile in "${kubernetes_profiles[@]}"; do
            echo "Creating kubernetes profile"
            cat "${kubernetes_profile}"
            # pks create-kubernetes-profile "${kubernetes_profile}"
        done
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
