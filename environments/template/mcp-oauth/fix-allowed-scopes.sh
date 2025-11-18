#!/usr/bin/env bash
#
# Fix Allowed Client Scopes Policy for DCR
# Adds mcp:run to the list of allowed scopes
#

set -euo pipefail

KEYCLOAK_URL="https://auth.aws.kane.mx/auth"
REALM="mcp"
ADMIN_USER="keycloak_admin"
ADMIN_PASS="fX0a4m2a5rqsMUlApqLctL4tdpYIFx"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Fix Allowed Client Scopes for DCR"
echo "=========================================="
echo ""

# Get admin token
echo -e "${BLUE}Authenticating...${NC}"
ADMIN_TOKEN=$(curl -s -X POST \
  "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=${ADMIN_USER}" \
  -d "password=${ADMIN_PASS}" \
  | jq -r '.access_token')

if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
  echo -e "${RED}✗ Authentication failed${NC}"
  exit 1
fi

echo -e "${GREEN}✓ Authenticated${NC}"
echo ""

# Get Allowed Client Scopes components
echo -e "${BLUE}Finding Allowed Client Scopes policies...${NC}"
COMPONENTS=$(curl -s -X GET \
  "${KEYCLOAK_URL}/admin/realms/${REALM}/components" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  | jq '[.[] | select(.providerId == "allowed-client-templates" and .providerType == "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy")]')

COMPONENT_COUNT=$(echo "$COMPONENTS" | jq 'length')
echo -e "${GREEN}✓ Found ${COMPONENT_COUNT} policy components${NC}"
echo ""

# Update each component
for i in $(seq 0 $(($COMPONENT_COUNT - 1))); do
    COMPONENT_ID=$(echo "$COMPONENTS" | jq -r ".[$i].id")
    COMPONENT_NAME=$(echo "$COMPONENTS" | jq -r ".[$i].name")
    
    echo -e "${BLUE}Updating: ${COMPONENT_NAME} (${COMPONENT_ID})${NC}"
    
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
        -H "Authorization: Bearer ${ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        -d '{
            "id": "'"${COMPONENT_ID}"'",
            "name": "'"${COMPONENT_NAME}"'",
            "providerId": "allowed-client-templates",
            "providerType": "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy",
            "parentId": "'"${REALM}"'",
            "config": {
                "allow-default-scopes": ["true"],
                "allowed-client-scopes": [
                    "openid",
                    "profile",
                    "email",
                    "mcp:run",
                    "offline_access",
                    "address",
                    "phone",
                    "roles",
                    "web-origins",
                    "microprofile-jwt",
                    "acr"
                ]
            }
        }')
    
    HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
    
    if [ "$HTTP_STATUS" == "204" ] || [ "$HTTP_STATUS" == "200" ]; then
        echo -e "${GREEN}  ✓ Updated successfully${NC}"
    else
        echo -e "${RED}  ✗ Update failed (HTTP ${HTTP_STATUS})${NC}"
        echo "$RESPONSE" | sed '/HTTP_STATUS/d'
    fi
    echo ""
done

# Test DCR
echo -e "${BLUE}Testing Dynamic Client Registration...${NC}"
TEST_CLIENT_NAME="test-dcr-$(date +%s)"

DCR_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
  "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
  -H "Content-Type: application/json" \
  -d "{
    \"client_name\": \"${TEST_CLIENT_NAME}\",
    \"redirect_uris\": [\"http://localhost:3000/callback\"],
    \"grant_types\": [\"authorization_code\", \"refresh_token\"],
    \"response_types\": [\"code\"],
    \"token_endpoint_auth_method\": \"none\",
    \"scope\": \"openid profile email mcp:run offline_access\"
  }")

DCR_STATUS=$(echo "$DCR_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
DCR_BODY=$(echo "$DCR_RESPONSE" | sed '/HTTP_STATUS/d')

if [ "$DCR_STATUS" == "201" ] || [ "$DCR_STATUS" == "200" ]; then
    echo -e "${GREEN}✓ DCR test successful!${NC}"
    CLIENT_ID=$(echo "$DCR_BODY" | jq -r '.client_id')
    echo "  Client ID: $CLIENT_ID"
    
    # Cleanup
    REG_TOKEN=$(echo "$DCR_BODY" | jq -r '.registration_access_token')
    curl -s -X DELETE \
        "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect/${CLIENT_ID}" \
        -H "Authorization: Bearer ${REG_TOKEN}" > /dev/null
    echo -e "${GREEN}  ✓ Test client cleaned up${NC}"
else
    echo -e "${RED}✗ DCR test still failing (HTTP ${DCR_STATUS})${NC}"
    echo "$DCR_BODY" | jq '.'
    exit 1
fi

echo ""
echo "=========================================="
echo -e "${GREEN}✓ Configuration Complete!${NC}"
echo "=========================================="
echo ""
echo "Dynamic Client Registration now allows:"
echo "  - openid, profile, email (standard)"
echo "  - mcp:run (custom scope)"
echo "  - offline_access (refresh tokens)"
echo ""
echo "Now retry the full flow test:"
echo "  ./test-dcr-full-flow.sh"
echo ""
