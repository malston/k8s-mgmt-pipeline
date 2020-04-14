#!/bin/bash

##
## "config-repo" is the foundation-specific configuration repo; each directory in there is
## to be a cluster on that namespace
##
for clusters in ./config-repo/*; do
  ##
  ## Text files cannot be clusters... so let's skip those
  ##
  if [[ ! -d config-repo/${clusters} ]]; then
    continue
  fi

  ##
  ## Set the directory name to be the cluster we need to login to, and do the login
  ##
  export K8S_CLUSTER=${clusters}
  # ./k8s-management/generic-tasks/common/login-k8s.sh
  # echo
  
  ##
  ## Drop down into cluster directory
  ##
  cd "${TOP_DIR}/config-repo/${clusters}" || echo "${TOP_DIR}/config-repo/${clusters} does not exist"; exit 1

  ## This first loop is the "create" section

  ##
  ## Stash the list of live namespaces into an array for referencing later
  ##
  LIVE_NAMESPACES=( "$(kubectl get namespaces -o json | jq -r '.items[].metadata.name')" )
  
  ##
  ## Use find to get the list of directories - where each directory is to be a namespace inside
  ## this cluster
  ##
  for namespace in $(find . -mindepth 1 -maxdepth 1 -not -path '*/\.*' -type d | cut -d"/" -f2); do
    ##
    ## Get the list of namespaces in this cluster and then check to ensure there is a matching
    ## directory. If the directory exists AND the namespace is already there, echo a helpful
    ## message and continue on
    if [[ "${LIVE_NAMESPACES[*]} " =~ ${namespace} ]]; then
      echo "${namespace} already exists. skipping creation"
      echo ""
    fi
  
    ##
    ## Conversely, if the namespace wasn't found, it gets created here
    ##
    if [[ ! "${LIVE_NAMESPACES[*]} " =~ ${namespace} ]]; then
      echo "creating namespace ${namespace}"
      kubectl create ns "${namespace}"
      kubectl label ns "${namespace}" "name=${namespace}"
      echo ""
    fi
  done

  ##
  ## This second loop is the "delete" section
  ##
  for ns in "${LIVE_NAMESPACES[@]}"; do
    ##
    ## The protected-ns.yml file contains namespaces which are required to be in existence, so make sure
    ## not to delete those
    ##
    CHECK=$(bosh int ../protected-ns.yml --path /protected_ns | grep ${ns} | cut-d' ' -f2)
    if [[ ${CHECK} == "${ns}"  ]]; then
      echo "${ns} is a protected namespace. skipping delete"
      continue
      echo ""
    fi
    ##
    ## Otherwise, remove the namespace (which will automatically remove any namespace-scoe resources,
    ## e.g.: pods, deployments, virtualservices, etc.)
    ##
    if [[ ! -d ${ns}  ]]; then
      echo "Deleting namespace ${ns} from cluster ${clusters}..."
      kubectl delete ns "${ns}"
      echo ""
    fi
  done
done