#!/bin/bash

set -e
# only exit with zero if all commands of the pipeline exit successfully
set -o pipefail

__CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
[[ -f "${__CWD}/target-bosh.sh" ]] &&  \
  source "${__CWD}/target-bosh.sh" ||  \
  echo "target-bosh.sh not found"

ADMIN_CLIENT_SECRET=$(om credentials \
    -p pivotal-container-service \
    -c '.properties.pks_uaa_management_admin_client' \
    -f secret)

om credentials \
  -p pivotal-container-service \
  --credential-reference .pivotal-container-service.pks_tls \
  --credential-field cert_pem > /tmp/pks-ca.crt

uaac target "${PKS_API_URL}:8443" --ca-cert /tmp/pks-ca.crt
uaac token client get admin -s "${ADMIN_CLIENT_SECRET}"

uaac user add malston --emails malston@vmware.com -p password
uaac member add pks.cluster.manage malston

uaac client add pksadmin \
	-s randomly-generated-secret \
	--authorized_grant_types client_credentials  \
	--authorities pks.clusters.admin