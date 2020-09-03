#!/bin/bash -e

if [ -z "${PKS_API_URL}" ]; then
  echo "Enter pks url: (e.g., https://api.pks.example.com)"
  read -r PKS_API_URL
fi

ADMIN_CLIENT_SECRET=$(om credentials \
    -p pivotal-container-service \
    -c '.properties.pks_uaa_management_admin_client' \
    -f secret)

printf "\n\npks_uaa_management_admin_client: %s\n\n" "${ADMIN_CLIENT_SECRET}"

om credentials \
  -p pivotal-container-service \
  --credential-reference .pivotal-container-service.pks_tls \
  --credential-field cert_pem > /tmp/pks-ca.crt

uaac target "${PKS_API_URL}:8443" --ca-cert /tmp/pks-ca.crt
uaac token client get admin -s "${ADMIN_CLIENT_SECRET}"

uaac member add pks.clusters.admin cody