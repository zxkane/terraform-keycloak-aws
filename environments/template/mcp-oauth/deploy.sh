#!/usr/bin/env bash
#
# Integrated MCP OAuth Realm Deployment
# Manages: Terraform resources + Client Registration Policies
#
# Usage: ./deploy.sh [plan|apply|destroy]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ACTION="${1:-apply}"

KEYCLOAK_URL="https://auth.aws.kane.mx/auth"
REALM="mcp"
ADMIN_USER="keycloak_admin"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Get admin password from terraform.tfvars
get_admin_password() {
    grep "^keycloak_admin_password" terraform.tfvars 2>/dev/null | cut -d'"' -f2
}

# Get admin token
get_admin_token() {
    local password=$1
    curl -s -X POST \
        "${KEYCLOAK_URL}/realms/master/protocol/openid-connect/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "grant_type=password" \
        -d "client_id=admin-cli" \
        -d "username=${ADMIN_USER}" \
        -d "password=${password}" \
        | jq -r '.access_token'
}

# Configure DCR policies using Components API
configure_dcr_policies() {
    local admin_token=$1

    echo -e "${BLUE}Configuring Client Registration Policies...${NC}"

    # Find Trusted Hosts component
    COMPONENT_ID=$(curl -s -X GET \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/components" \
        -H "Authorization: Bearer ${admin_token}" \
        | jq -r '.[] | select(.providerId == "trusted-hosts" and .providerType == "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy") | .id' \
        | head -1)

    if [ -z "$COMPONENT_ID" ] || [ "$COMPONENT_ID" == "null" ]; then
        echo -e "${YELLOW}⚠ Trusted Hosts component not found${NC}"
        return 1
    fi

    echo "  Found component: $COMPONENT_ID"

    # Update policy
    RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X PUT \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
        -H "Authorization: Bearer ${admin_token}" \
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

    if [ "$HTTP_STATUS" == "204" ] || [ "$HTTP_STATUS" == "200" ]; then
        echo -e "${GREEN}  ✓ Trusted Hosts policy updated${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ Update returned HTTP $HTTP_STATUS${NC}"
        return 1
    fi
}

# Test DCR
test_dcr() {
    echo -e "${BLUE}Testing Dynamic Client Registration...${NC}"

    TEST_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
        "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
        -H "Content-Type: application/json" \
        -d "{
            \"client_name\": \"test-dcr-$(date +%s)\",
            \"redirect_uris\": [\"http://localhost:3000/callback\"]
        }")

    HTTP_STATUS=$(echo "$TEST_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
    BODY=$(echo "$TEST_RESPONSE" | sed '/HTTP_STATUS/d')

    if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "200" ]; then
        echo -e "${GREEN}✓ DCR working!${NC}"
        CLIENT_ID=$(echo "$BODY" | jq -r '.client_id')
        echo "  Client ID: $CLIENT_ID"
        
        # Cleanup
        REG_TOKEN=$(echo "$BODY" | jq -r '.registration_access_token')
        curl -s -X DELETE \
            "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect/${CLIENT_ID}" \
            -H "Authorization: Bearer ${REG_TOKEN}" > /dev/null
        return 0
    else
        echo -e "${YELLOW}⚠ DCR still blocked (HTTP $HTTP_STATUS)${NC}"
        echo "$BODY" | jq '.'
        return 1
    fi
}

# Main
case "$ACTION" in
    plan)
        terraform plan
        ;;

    apply)
        echo "=========================================="
        echo "Phase 1: Terraform Resources"
        echo "=========================================="
        terraform apply -auto-approve

        if [ $? -ne 0 ]; then
            echo -e "${RED}✗ Terraform failed${NC}"
            exit 1
        fi

        echo ""
        echo "=========================================="
        echo "Phase 2: Client Registration Policies"
        echo "=========================================="

        ADMIN_PASS=$(get_admin_password)

        if [ -z "$ADMIN_PASS" ]; then
            echo -e "${YELLOW}⚠ Admin password not found${NC}"
            echo "  Run manually: ./update-dcr-policy.sh"
            exit 0
        fi

        ADMIN_TOKEN=$(get_admin_token "$ADMIN_PASS")

        if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
            echo -e "${YELLOW}⚠ Failed to authenticate${NC}"
            exit 0
        fi

        configure_dcr_policies "$ADMIN_TOKEN" && test_dcr

        echo ""
        echo "=========================================="
        echo -e "${GREEN}✓ Deployment Complete!${NC}"
        echo "=========================================="
        echo ""
        echo "Claude Code command:"
        echo "  claude mcp add --transport http xiaozhi2 \\"
        echo "    https://xiaozhi2-logs5gh9ak.gateway.bedrock-agentcore.us-west-2.amazonaws.com/mcp"
        echo ""
        echo "Then in Claude Code: /mcp"
        ;;

    destroy)
        terraform destroy -auto-approve
        ;;

    *)
        echo "Usage: $0 [plan|apply|destroy]"
        exit 1
        ;;
esac
