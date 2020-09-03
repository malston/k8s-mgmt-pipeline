#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

function usage() {
    echo "Usage:"
    echo "  $0 [flags]"
    echo ""
    echo "Examples:"
    printf "  %s \ \n      --api=api.pks.dev.example.com " "$0"
    printf "\ \n      --cluster=cluster1 "
    printf "\ \n      --domain=cluster1.pks.dev.example.com "
    printf "\ \n      --ca-cert=/tmp/pks-ca.crt "
    printf "\ \n      --sso\n"
    printf "\n"
    printf "  %s \ \n      --api=api.pks.dev.example.com " "$0"
    printf "\ \n      --cluster=cluster1.pks.dev.example.com "
    printf "\ \n      --user=admin "
    printf "\n\n"
    echo "Flags:"
    printf "%s, --help\n" "-h"
    printf "%s, --api string\tThe PKS API server FQDN\n" "-a"
    printf "%s, --cluster string\tThe Kubernetes cluster name\n" "-c"
    printf "%s, --domain string\tThe Kubernetes cluster FQDN\n" "-d"
    printf "%s, --namespace string\tThe Kubernetes namespace\n" "-n"
    printf "%s, --user string\tUsername\n" "-u"
    printf "%s, --password string\tPassword\n" "-p"
    printf "%s string\tPath to CA cert file to connect to the Kubernetes API server\n" "--ca-cert"
    printf "%s\t\t\tPrompt for a one-time passcode to do Single sign-on\n\n" "--sso"
    echo "Environment Variables:"
    echo -e "UAA_PORT, default 8443\tSets the PKS API server and Kubernetes Master server port\n"
}

function get_username_from_token() {
    claims=$(echo "${payload}" | base64 --decode)
    username=$(echo "${claims}" | jq -r .user_name 2>&1)
    if [[ -z "$username" || $? != 0 ]]; then
        return 1
    fi
    echo "$username"
}

function parse_access_token() {
    # Access token is a string delimited by dots into three parts:
    # header, payload, and signature
    local access_token="${1}"

    IFS='.' read -ra parts <<< "$access_token"

    if [[ ${#parts[@]} != 3 ]]; then
        echo "token contains an invalid number of segments"
        return 1
    fi

    payload="${parts[1]}"
    username=$(get_username_from_token "${payload}")
    
    if [[ $? != 0 ]]; then
        payload="${payload}=="
        username=$(get_username_from_token "${payload}")
        if [[ -z "$username" || $? != 0 ]]; then
            echo "token doesn't contains user_name claim"
            return 1
        fi
    fi

    echo "$username"
}

function create_kubeconfig() {
    local uaa_tokens="${1}"
    local auth_url="${2}"
    local user="${3}"
    local cluster="${4}"
    local cluster_domain="${5}"
    local namespace="${6}"
    local client_id="${7}"
    local client_secret="${8}"
    local ca_cert="${9}"
    local cluster_port="${UAA_PORT:-8443}"

    if [[ -z "${user}" ]]; then
        access_token=$(echo "${uaa_tokens}" | cut -d, -f1 | cut -d: -f2 | sed -e s/\"//g)
        user=$(parse_access_token "${access_token}" 2>&1) || (echo "$user" && exit 1)
    fi

    id_token=$(echo "${uaa_tokens}" | cut -d, -f3 | cut -d: -f2 | sed -e s/\"//g)
    refresh_token=$(echo "${uaa_tokens}" | cut -d, -f4 | cut -d: -f2 | sed -e s/\"//g)

    # Construct kubeconfig
    skip_ssl_validation=""
    if [[ -z "$ca_cert" ]]; then
        skip_ssl_validation="--insecure-skip-tls-verify"
        kubectl config set-cluster "${cluster}" --server="https://${cluster_domain}:${cluster_port}" "${skip_ssl_validation}"
    else
        kubectl config set-cluster "${cluster}" --server="https://${cluster_domain}:${cluster_port}" --certificate-authority="${ca_cert}"
    fi

    kubectl config set-context "${cluster}" --cluster="${cluster}" --user="${user}" --namespace="${namespace}"
    kubectl config use-context "${cluster}"

    kubectl config set-credentials "${user}" \
        --auth-provider oidc \
        --auth-provider-arg client-id="${client_id}" \
        --auth-provider-arg cluster_client_secret="${client_secret}" \
        --auth-provider-arg id-token="${id_token}" \
        --auth-provider-arg idp-issuer-url="${auth_url}/oauth/token" \
        --auth-provider-arg refresh-token="${refresh_token}"
}

function urlencode() {
    local l=${#1}
    for (( i = 0 ; i < l ; i++ )); do
        local c=${1:i:1}
        case "$c" in
            [a-zA-Z0-9.~_-]) printf "%s" "$c" ;;
            ' ') printf + ;;
            *) printf '%%%.2X' "'$c"
        esac
    done
}

function sso_url() {
    local passcode="${1}"
    local auth_url="${2}"
    local redirect_uri="${3}"
    local client_id="${4}"

    response_type="id_token"
    grant_type="authorization_code"
    client_secret=""

    curl_cmd="curl '${auth_url}/oauth/token' -sk -X POST \
        -H 'Accept: application/json' \
        -H 'Content-Type: application/x-www-form-urlencoded' \
        -d \"client_id=${client_id}&client_secret=\"${client_secret}\"&grant_type=${grant_type}&code=\"${passcode}\"&response_type=${response_type}&redirect_uri=\"${redirect_uri}\"\""

    echo "$curl_cmd"
}

function password_url() {
    local auth_url="${1}"
    local user="${2}"
    local password="${3}"

    client_id="pks_cluster_client"
    client_secret=""

    curl_cmd="curl '${auth_url}/oauth/token' -sk -X POST \
        -H 'Accept: application/json' \
        -d \"client_id=${client_id}&client_secret=\"${client_secret}\"&grant_type=password&username=${user}&password=\"${password}\"&response_type=id_token\""

    echo "$curl_cmd"
}

function read_password() {
    unset password
    prompt="Password: "
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt='*'
        password+="$char"
    done
    echo "$password"
}

function read_passcode() {
    unset passcode
    prompt="Passcode: "
    while IFS= read -p "$prompt" -r -s -n 1 char
    do
        if [[ $char == $'\0' ]]
        then
            break
        fi
        prompt='*'
        passcode+="$char"
    done
    echo "$passcode"
}

function main() {
    local api="${1}"
    local user="${2}"
    local password="${3}"
    local cluster="${4}"
    local cluster_domain="${5}"
    local namespace="${6}"
    local ca_cert="${7}"
    local sso="${8}"
    local uaa_port="${UAA_PORT:-8443}"

    client_id="pks_cluster_client"
    client_secret=""
    auth_url="https://${api}:${uaa_port}"


    if [[ -n $sso ]]; then
        redirect_uri=$(urlencode "${auth_url}")
        printf "One Time Code ( Open A Web Browser to the following URL to get a Code: %s/oauth/authorize?response_type=code&client_id=%s&redirect_uri=%s )\n" "${auth_url}" "${client_id}" "${redirect_uri}"
        passcode=$(read_passcode)
        curl_cmd=$(sso_url "${passcode}" "${auth_url}" "${redirect_uri}" "${client_id}")
    else
        password_input="${PKS_PASSWORD}"
        if [[ -z "${password_input}" ]]; then
            password_input=$(read_password)
        fi
        password=$(urlencode "$password_input")
        curl_cmd=$(password_url "${auth_url}" "${user}" "${password}")
    fi

    uaa_tokens=$(eval "$curl_cmd")

    if [[ ${uaa_tokens} =~ unauthorized|Error ]]; then
        error_description=$(echo "${uaa_tokens}" | cut -d, -f2 | cut -d: -f2 | sed -e s/\"//g | sed -e s/\}//g)
        echo
        echo "${error_description}"
        exit 1
    fi

    echo ""
    create_kubeconfig "$uaa_tokens" "$auth_url" "$user" "$cluster" "$cluster_domain" "$namespace" "$client_id" "$client_secret" "$ca_cert"
}

if [ "$#" -lt 3 ]; then
    usage
    exit 1
fi

while [ "$1" != "" ]; do
    param=$(echo "$1" | awk -F= '{print $1}')
    value=$(echo "$1" | awk -F= '{print $2}')
    case $param in
        -h | --help)
            usage
            exit
            ;;
        -a | --api)
            PKS_API=$value
            ;;
        -c | --cluster)
            PKS_CLUSTER=$value
            ;;
        -d | --domain)
            PKS_CLUSTER_DOMAIN=$value
            ;;
        -u | --user)
            PKS_USER=$value
            ;;
        -p | --password)
            PKS_PASSWORD=$value
            ;;
        -n | --namespace)
            PKS_NAMESPACE=$value
            ;;
        --sso)
            PKS_SSO=true
            ;;
        --ca-cert)
            PKS_CLUSTER_CERT=$value
            ;;
        *)
            echo ""
            echo "Invalid option: [$param]"
            echo ""
            usage
            exit 1
            ;;
    esac
    shift
done

if [[ -z "$PKS_SSO" && -z "$PKS_USER" ]]; then
    echo ""
    echo "Must specify '--user' flag if '--sso' flag not provided"
    echo ""
    usage
    exit 1
fi

if [[ -z "$PKS_API" ]]; then
    echo ""
    echo "Must specify '-a | --api'"
    echo ""
    usage
    exit 1
fi

if [[ -z "$PKS_CLUSTER" ]]; then
    echo ""
    echo "Must specify '-c | --cluster'"
    echo ""
    usage
    exit 1
fi

if [[ -z "$PKS_CLUSTER_DOMAIN" ]]; then
    echo ""
    echo "Must specify '-d | --domain'"
    echo ""
    usage
    exit 1
fi

if [[ -z "$PKS_NAMESPACE" ]]; then
    PKS_NAMESPACE="default"
fi

main "${PKS_API}" "${PKS_USER}" "${PKS_PASSWORD}" "${PKS_CLUSTER}" "${PKS_CLUSTER_DOMAIN}" "${PKS_NAMESPACE}" "${PKS_CLUSTER_CERT}" "${PKS_SSO}"
