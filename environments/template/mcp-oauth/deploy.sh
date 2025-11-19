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

# Load configuration from terraform.tfvars
source "${SCRIPT_DIR}/load-config.sh"

# Use variables from config
REALM="${REALM_NAME}"
ADMIN_USER="${KEYCLOAK_ADMIN_USERNAME}"
ADMIN_PASS="${KEYCLOAK_ADMIN_PASSWORD}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

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

# Delete Trusted Hosts policy to allow all redirect URI schemes (MCP clients)
delete_trusted_hosts_policy() {
    local admin_token=$1

    echo -e "${BLUE}Disabling Trusted Hosts Policy (for MCP clients)...${NC}"

    # Find Trusted Hosts component for anonymous DCR
    COMPONENT_ID=$(curl -s -X GET \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/components" \
        -H "Authorization: Bearer ${admin_token}" \
        | jq -r '.[] | select(.providerId == "trusted-hosts" and .providerType == "org.keycloak.services.clientregistration.policy.ClientRegistrationPolicy" and .subType == "anonymous") | .id' \
        | head -1)

    if [ -z "$COMPONENT_ID" ] || [ "$COMPONENT_ID" == "null" ]; then
        echo -e "${YELLOW}⚠ Trusted Hosts component not found (may already be deleted)${NC}"
        return 0
    fi

    echo "  Found component: $COMPONENT_ID"
    echo "  Deleting to allow cursor://, vscode://, and all URI schemes..."

    # Delete the component
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/components/${COMPONENT_ID}" \
        -H "Authorization: Bearer ${admin_token}")

    if [ "$HTTP_CODE" == "204" ] || [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}  ✓ Trusted Hosts policy deleted${NC}"
        echo -e "  ${GREEN}✓ MCP clients (Claude Code, Cursor, VS Code) can now register${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ Delete returned HTTP $HTTP_CODE${NC}"
        return 1
    fi
}

# Configure Realm Default Scopes to include mcp:run
configure_realm_default_scopes() {
    local admin_token=$1

    echo -e "${BLUE}Configuring Realm Default Scopes...${NC}"

    # Get mcp:run scope ID
    MCP_RUN_ID=$(curl -s -X GET \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/client-scopes" \
        -H "Authorization: Bearer ${admin_token}" \
        | jq -r '.[] | select(.name == "mcp:run") | .id')

    if [ -z "$MCP_RUN_ID" ] || [ "$MCP_RUN_ID" == "null" ]; then
        echo -e "${YELLOW}⚠ mcp:run scope not found${NC}"
        return 1
    fi

    echo "  mcp:run scope ID: $MCP_RUN_ID"

    # Check if already in realm defaults
    HAS_SCOPE=$(curl -s -X GET \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/default-default-client-scopes" \
        -H "Authorization: Bearer ${admin_token}" \
        | jq -r '.[] | select(.name == "mcp:run") | .id')

    if [ -n "$HAS_SCOPE" ]; then
        echo -e "${GREEN}  ✓ mcp:run already in realm default scopes${NC}"
        return 0
    fi

    # Add to realm default scopes
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
        "${KEYCLOAK_URL}/admin/realms/${REALM}/default-default-client-scopes/${MCP_RUN_ID}" \
        -H "Authorization: Bearer ${admin_token}")

    if [ "$HTTP_CODE" == "204" ] || [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}  ✓ mcp:run added to realm default scopes${NC}"
        echo -e "  ${GREEN}✓ All new DCR clients will auto-inherit mcp:run${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ Update returned HTTP $HTTP_CODE${NC}"
        return 1
    fi
}

# Test DCR with MCP client URI schemes
test_dcr() {
    echo -e "${BLUE}Testing Dynamic Client Registration (MCP clients)...${NC}"

    # Test with cursor:// URI (used by Claude Code and Cursor)
    TEST_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
        "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect" \
        -H "Content-Type: application/json" \
        -d "{
            \"client_name\": \"test-mcp-dcr-$(date +%s)\",
            \"redirect_uris\": [\"cursor://test/callback\", \"http://localhost:3000/callback\"],
            \"grant_types\": [\"authorization_code\", \"refresh_token\"],
            \"response_types\": [\"code\"],
            \"token_endpoint_auth_method\": \"none\"
        }")

    HTTP_STATUS=$(echo "$TEST_RESPONSE" | grep "HTTP_STATUS" | cut -d':' -f2)
    BODY=$(echo "$TEST_RESPONSE" | sed '/HTTP_STATUS/d')

    if [ "$HTTP_STATUS" == "201" ] || [ "$HTTP_STATUS" == "200" ]; then
        echo -e "${GREEN}✓ DCR working with MCP client URIs!${NC}"
        CLIENT_ID=$(echo "$BODY" | jq -r '.client_id')
        echo "  Client ID: $CLIENT_ID"
        echo "  Redirect URIs: cursor://test/callback, http://localhost:3000/callback"

        # Check if mcp:run is in default scopes
        echo -e "${BLUE}  Verifying mcp:run scope...${NC}"
        SCOPES=$(echo "$BODY" | jq -r '.scope // "unknown"')
        if echo "$SCOPES" | grep -q "mcp:run"; then
            echo -e "${GREEN}  ✓ mcp:run scope present${NC}"
        else
            echo -e "${YELLOW}  ⚠ mcp:run scope missing (may need manual configuration)${NC}"
        fi

        # Cleanup
        REG_TOKEN=$(echo "$BODY" | jq -r '.registration_access_token')
        curl -s -X DELETE \
            "${KEYCLOAK_URL}/realms/${REALM}/clients-registrations/openid-connect/${CLIENT_ID}" \
            -H "Authorization: Bearer ${REG_TOKEN}" > /dev/null 2>&1
        return 0
    else
        echo -e "${YELLOW}⚠ DCR failed (HTTP $HTTP_STATUS)${NC}"
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
        echo "Phase 2: MCP Client Configuration"
        echo "=========================================="

        # ADMIN_PASS already loaded from load-config.sh
        if [ -z "$ADMIN_PASS" ]; then
            echo -e "${YELLOW}⚠ Admin password not found${NC}"
            echo "  Set keycloak_admin_password in terraform.tfvars"
            echo "  Or run manually: ./fix-allowed-scopes.sh && ./disable-trusted-hosts.sh"
            exit 0
        fi

        ADMIN_TOKEN=$(get_admin_token "$ADMIN_PASS")

        if [ -z "$ADMIN_TOKEN" ] || [ "$ADMIN_TOKEN" == "null" ]; then
            echo -e "${YELLOW}⚠ Failed to authenticate${NC}"
            exit 0
        fi

        # Configure for MCP clients (Claude Code, Cursor, VS Code)
        delete_trusted_hosts_policy "$ADMIN_TOKEN"
        configure_realm_default_scopes "$ADMIN_TOKEN"

        echo ""
        echo "Running scripts for additional DCR configuration..."
        ./fix-allowed-scopes.sh || echo -e "${YELLOW}⚠ fix-allowed-scopes.sh not available${NC}"

        echo ""
        test_dcr

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
