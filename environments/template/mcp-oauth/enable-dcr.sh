#!/usr/bin/env bash
#
# Enable Dynamic Client Registration (DCR) for MCP
# Configures Keycloak to allow Claude Code to register clients dynamically
#

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load configuration from terraform.tfvars
source "${SCRIPT_DIR}/load-config.sh"

# Use variables from config
REALM="${REALM_NAME}"
ADMIN_USER="${KEYCLOAK_ADMIN_USERNAME}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"

echo "=========================================="
echo "Enable MCP Dynamic Client Registration"
echo "=========================================="
echo "Keycloak URL: ${KEYCLOAK_URL}"
echo "Realm: ${REALM}"
echo ""

# Step 1: Get admin token
echo "Step 1: Authenticating..."
ADMIN_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
  echo "✗ Authentication failed"
  exit 1
fi
echo "✓ Authenticated"
echo ""

# Step 2: Update Trusted Hosts policy
echo "Step 2: Configuring Trusted Hosts policy..."
echo "  (Disabling host verification for Claude Code DCR)"

# Get current configuration
curl -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-registration/default" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  > /tmp/current-reg-config.json

echo "  Current configuration saved"

# Update with permissive settings for DCR
curl -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-registration/default" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "clientRegistrationPolicies": [
      {
        "name": "Trusted Hosts",
        "providerId": "trusted-hosts",
        "config": {
          "host-sending-registration-request-must-match": ["false"],
          "client-uris-must-match": ["false"]
        }
      },
      {
        "name": "Allowed Client Scopes",
        "providerId": "allowed-client-templates",
        "config": {
          "allow-default-scopes": ["true"],
          "allowed-client-scopes": ["openid", "profile", "email", "mcp:run", "offline_access"]
        }
      },
      {
        "name": "Max Clients",
        "providerId": "max-clients",
        "config": {
          "max-clients": ["500"]
        }
      }
    ]
  }' > /tmp/update-result.json 2>&1

if grep -q "error" /tmp/update-result.json 2>/dev/null; then
  echo "  ⚠ Update may have failed:"
  cat /tmp/update-result.json | jq '.' 2>/dev/null || cat /tmp/update-result.json
else
  echo "  ✓ Policy updated"
fi
echo ""

# Step 3: Test DCR
echo "Step 3: Testing Dynamic Client Registration..."
TEST_CLIENT_NAME="test-dcr-$(date +%s)"

TEST_RESPONSE=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_name\": \"${TEST_CLIENT_NAME}\",
    \"redirect_uris\": [\"http://localhost:3000/callback\"],
    \"grant_types\": [\"authorization_code\"],
    \"response_types\": [\"code\"],
    \"token_endpoint_auth_method\": \"none\"
  }")

if echo "$TEST_RESPONSE" | jq -e '.client_id' > /dev/null 2>&1; then
  echo "✓ DCR test successful!"
  echo "$TEST_RESPONSE" | jq '{client_id, client_name, registration_access_token}'
  
  # Clean up test client
  CLIENT_ID=$(echo "$TEST_RESPONSE" | jq -r '.client_id')
  REG_TOKEN=$(echo "$TEST_RESPONSE" | jq -r '.registration_access_token')
  
  echo ""
  read -p "Delete test client? (y/n): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -s -X DELETE \
      "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect/${CLIENT_ID}" \
      -H "Authorization: Bearer ${REG_TOKEN}" > /dev/null
    echo "✓ Test client deleted"
  fi
else
  echo "✗ DCR test failed:"
  echo "$TEST_RESPONSE" | jq '.'
  echo ""
  echo "Troubleshooting:"
  echo "1. Check Keycloak Admin Console: Realm Settings → Client Registration"
  echo "2. Verify 'Trusted Hosts' policy allows anonymous registration"
  echo "3. Check server logs for detailed errors"
fi

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Dynamic Client Registration endpoint:"
echo "  ${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect"
echo ""
echo "Claude Code command:"
echo "  claude mcp add --transport http xiaozhi2 \\"
echo "    https://xiaozhi2-logs5gh9ak.gateway.bedrock-agentcore.us-west-2.amazonaws.com/mcp"
echo ""
echo "Then use /mcp in Claude Code to authenticate"
echo ""
