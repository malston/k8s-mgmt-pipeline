#!/bin/bash

##
## "config-repo" is the foundation-specific configuration repo; each directory in there is
## to be a cluster on that namespace
##
for clusters in $(ls ./config-repo); do
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
  ./k8s-management/generic-tasks/common/login-k8s.sh
  echo
  
  ##
  ## Drop down into cluster directory
  ##
  cd ${TOP_DIR}/config-repo/${clusters}

  ## 
  ## Start by applying the ClusterRole, if it exists
  ##
  if [[ -f clusterRole.yml ]]; then
    echo "Apply clusterRole on cluster ${clusters}..."
    kubectl apply -f clusterRole.yml
    echo
  fi
  
  ##
  ## Use find to get the list of directories - wheere each directory is to be a namespace inside
  ## this cluster
  ##
  for namespace in $(find . -mindepth 1 -maxdepth 1 -not -path '*/\.*' -type d | cut -d"/" -f2); do
    ##
    ## Now apply the things...
    ##
    if [[ -f ${namespace}/role.yml ]]; then
      echo "Apply namespace role.yml on namespace ${namespace}..."
      kubectl apply -f ${namespace}/role.yml -n ${namespace}
    fi
    if [[ -f ${namespace}/roleBinding.yml ]]; then
      echo "Apply namespace roleBinding.yml on namespace ${namespace}..."
      kubectl apply -f ${namespace}/roleBinding.yml -n ${namespace}
    fi
    if [[ -f ${namespace}/clusterRolebinding.yml ]]; then
      echo "Apply namespace clusterRolebinding on namespace ${namespace}..."
      kubectl apply -f ${namespace}/clusterRolebinding.yml -n ${namespace}
    fi
  done
  echo
done