#!/usr/bin/env bash
set -euo pipefail

KEYCLOAK_URL="https://auth.aws.kane.mx/auth"
REALM="mcp"
ADMIN_USER="keycloak_admin"
ADMIN_PASS="fX0a4m2a5rqsMUlApqLctL4tdpYIFx"

echo "Updating Trusted Hosts policy for DCR..."

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

# Update configuration
echo "Updating configuration..."
RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "'"${COMPONENT_ID}"'",
    "name": "Trusted Hosts",
    "providerId": "trusted-hosts",
    "providerType": "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy",
    "parentId": "'"${REALM}"'",
    "config": {
      "host-sending-registration-request-must-match": ["false"],
      "client-uris-must-match": ["true"],
      "trusted-hosts": ["localhost", "127.0.0.1"]
    }
  }')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$HTTP_STATUS" == "204" ] || [ "$HTTP_STATUS" == "200" ]; then
    echo "✓ Trusted Hosts policy updated successfully!"
else
    echo "✗ Update failed (HTTP $HTTP_STATUS)"
    echo "$BODY"
    exit 1
fi

# Verify update
echo ""
echo "Verifying configuration..."
curl -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq '.config'

# Test DCR
echo ""
echo "Testing Dynamic Client Registration..."
DCR_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_name\": \"test-dcr-$(date +%s)\",
    \"redirect_uris\": [\"http://localhost:3000/callback\"],
    \"grant_types\": [\"authorization_code\"],
    \"response_types\": [\"code\"],
    \"token_endpoint_auth_method\": \"none\"
  }")

DCR_STATUS=$(echo "$DCR_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
DCR_BODY=$(echo "$DCR_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$DCR_STATUS" == "201" ] || [ "$DCR_STATUS" == "200" ]; then
    echo "✓ DCR test successful!"
    echo "$DCR_BODY" | jq '{client_id, client_name}'
    
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
echo "✓ Configuration complete and verified!"
