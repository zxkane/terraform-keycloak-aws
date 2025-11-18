#!/usr/bin/env bash
#
# Configure Keycloak Trusted Hosts for Dynamic Client Registration
# This script allows specific hosts to register clients dynamically
#

set -euo pipefail

KEYCLOAK_URL="https://auth.aws.kane.mx/auth"
REALM="mcp"
ADMIN_USER="keycloak_admin"
ADMIN_PASS="fX0a4m2a5rqsMUlApqLctL4tdpYIFx"

echo "=========================================="
echo "Keycloak Trusted Hosts Configuration"
echo "=========================================="
echo ""

# Step 1: Get admin access token
echo "Step 1: Authenticating as admin..."
ADMIN_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  | jq -r '.access_token')

if [ "$ADMIN_TOKEN" == "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo "Error: Failed to get admin token"
  exit 1
fi

echo "✓ Authentication successful"
echo ""

# Step 2: Get current client registration policies
echo "Step 2: Fetching current client registration policies..."
curl -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-registration-policy/providers" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq '.' > /tmp/policies.json

echo "✓ Current policies saved to /tmp/policies.json"
echo ""

# Step 3: Update Trusted Hosts policy
echo "Step 3: Updating Trusted Hosts policy..."
echo ""
echo "Option 1: Allow all hosts (development only)"
echo "Option 2: Allow specific hosts (recommended)"
echo ""
read -p "Choose option (1 or 2): " option

if [ "$option" == "1" ]; then
  # Disable trusted hosts check
  POLICY_CONFIG='{
    "trusted-hosts": {
      "hostSendingRegistrationRequestMustMatch": "*"
    }
  }'
  echo "Configuring: Allow all hosts (*)"
elif [ "$option" == "2" ]; then
  echo "Enter allowed hosts (comma-separated, e.g., localhost,127.0.0.1,example.com):"
  read -r hosts
  POLICY_CONFIG=$(cat <<EOF
{
  "trusted-hosts": {
    "hostSendingRegistrationRequestMustMatch": "$hosts",
    "clientUrisHostMustMatch": "$hosts"
  }
}
EOF
)
  echo "Configuring: Allow hosts: $hosts"
else
  echo "Invalid option"
  exit 1
fi

# Update the policy
curl -s -X PUT \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-registration-policy/providers/trusted-hosts" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$POLICY_CONFIG" \
  > /tmp/policy-update.json

echo ""
echo "✓ Policy updated"
echo ""

# Step 4: Verify the update
echo "Step 4: Verifying updated configuration..."
curl -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/client-registration-policy/providers/trusted-hosts" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq '.'

echo ""
echo "=========================================="
echo "Configuration Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Test Dynamic Client Registration:"
echo "   curl -X POST ${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"client_name\":\"test-client\"}'"
echo ""
echo "2. Retry your Claude Code MCP connection"
echo ""
