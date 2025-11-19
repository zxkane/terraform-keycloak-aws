#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration
source "${SCRIPT_DIR}/load-config.sh"

REALM="${REALM_NAME}"
ADMIN_USER="${KEYCLOAK_ADMIN_USERNAME}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"

echo "Disabling Trusted Hosts policy for DCR..."
echo "Keycloak URL: ${KEYCLOAK_URL}"
echo "Realm: ${REALM}"

# Get admin token
ADMIN_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
  echo "✗ Failed to authenticate"
  exit 1
fi
echo "✓ Authenticated"

# Get Trusted Hosts component ID
COMPONENT_ID=$(curl -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/components" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq -r '.[] | select(.providerId == "trusted-hosts" and .providerType == "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy") | .id' \
  | head -1)

if [ -z "$COMPONENT_ID" ] || [ "$COMPONENT_ID" == "null" ]; then
  echo "✗ Trusted Hosts component not found"
  exit 1
fi
echo "✓ Found Trusted Hosts component: $COMPONENT_ID"

# Delete the Trusted Hosts policy component
echo "Deleting Trusted Hosts policy..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X DELETE \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}")

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)

if [ "$HTTP_STATUS" == "204" ] || [ "$HTTP_STATUS" == "200" ]; then
    echo "✓ Trusted Hosts policy deleted successfully!"
else
    echo "✗ Delete failed (HTTP $HTTP_STATUS)"
    echo "$RESPONSE" | sed '/HTTP_STATUS/d'
    exit 1
fi

# Test DCR with cursor:// scheme
echo ""
echo "Testing DCR with cursor:// scheme..."
DCR_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_name\": \"test-cursor-$(date +%s)\",
    \"redirect_uris\": [\"cursor://test/callback\"],
    \"grant_types\": [\"authorization_code\"],
    \"response_types\": [\"code\"],
    \"token_endpoint_auth_method\": \"none\"
  }")

DCR_STATUS=$(echo "$DCR_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
DCR_BODY=$(echo "$DCR_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$DCR_STATUS" == "201" ] || [ "$DCR_STATUS" == "200" ]; then
    echo "✓ DCR test successful with cursor:// scheme!"
    echo "$DCR_BODY" | jq '{client_id, client_name, redirect_uris}'
    
    # Cleanup
    CLIENT_ID=$(echo "$DCR_BODY" | jq -r '.client_id')
    REG_TOKEN=$(echo "$DCR_BODY" | jq -r '.registration_access_token')
    curl -s -X DELETE \
      "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect/${CLIENT_ID}" \
      -H "Authorization: Bearer ${REG_TOKEN}" > /dev/null
    echo "✓ Test client cleaned up"
else
    echo "✗ DCR test failed (HTTP $DCR_STATUS)"
    echo "$DCR_BODY" | jq '.'
    exit 1
fi

echo ""
echo "=========================================="
echo "✓ Trusted Hosts policy disabled!"
echo "=========================================="
echo "All redirect URI schemes now allowed:"
echo "  - cursor://"
echo "  - vscode://"
echo "  - http://localhost"
echo "  - https://..."
