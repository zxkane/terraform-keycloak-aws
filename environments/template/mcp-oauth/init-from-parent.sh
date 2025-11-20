#!/usr/bin/env bash
#
# Initialize MCP OAuth terraform.tfvars from parent Keycloak deployment
# This script reads outputs from the parent Keycloak Terraform state
# and populates the mcp-oauth configuration automatically
#
# Usage: ./init-from-parent.sh [--gateway-url <url>]
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Initialize MCP OAuth from Parent Keycloak"
echo "=========================================="
echo ""

# Check if parent directory has Terraform state
if [ ! -f "${PARENT_DIR}/terraform.tfstate" ] && [ ! -f "${PARENT_DIR}/backend.tf" ]; then
  echo -e "${RED}✗ Parent Keycloak deployment not found${NC}"
  echo "  Expected: ${PARENT_DIR}"
  echo "  Make sure parent Keycloak is deployed first"
  exit 1
fi

echo -e "${BLUE}Reading configuration from parent Keycloak deployment...${NC}"
echo "  Parent: ${PARENT_DIR}"
echo ""

# Read configuration from parent terraform.tfvars (no Terraform state access needed)
cd "${PARENT_DIR}"

if [ ! -f "terraform.tfvars" ]; then
  echo -e "${RED}✗ Parent terraform.tfvars not found${NC}"
  echo "  Expected: ${PARENT_DIR}/terraform.tfvars"
  exit 1
fi

echo -e "${BLUE}Reading parent terraform.tfvars...${NC}"

# Parse values from parent tfvars
parse_parent_tfvar() {
  local key="$1"
  grep "^${key}\s*=" "${PARENT_DIR}/terraform.tfvars" | sed -E 's/.*=\s*"?([^"#]*)"?.*/\1/' | tr -d '"' | xargs
}

DNS_NAME=$(parse_parent_tfvar "dns_name")
ENV=$(parse_parent_tfvar "environment")
REGION=$(parse_parent_tfvar "region")

if [ -z "$DNS_NAME" ] || [ -z "$ENV" ] || [ -z "$REGION" ]; then
  echo -e "${RED}✗ Missing required values in parent terraform.tfvars${NC}"
  echo "  dns_name: ${DNS_NAME}"
  echo "  environment: ${ENV}"
  echo "  region: ${REGION}"
  exit 1
fi

# Construct Keycloak URL
KEYCLOAK_URL="https://${DNS_NAME}/auth"
echo -e "${GREEN}  ✓ Keycloak URL: ${KEYCLOAK_URL}${NC}"

# Construct SSM parameter path
SSM_PARAM="/keycloak/${ENV}/KEYCLOAK_PASSWORD"
echo -e "${GREEN}  ✓ SSM Parameter: ${SSM_PARAM}${NC}"

# Get admin password from AWS SSM
echo -e "${BLUE}Getting admin password from SSM (region: ${REGION})...${NC}"

# Try to get password with error output
SSM_RESULT=$(aws ssm get-parameter \
  --name "${SSM_PARAM}" \
  --with-decryption \
  --region "${REGION}" \
  --profile "${AWS_PROFILE:-default}" \
  --query 'Parameter.Value' \
  --output text 2>&1)

SSM_EXIT_CODE=$?

if [ $SSM_EXIT_CODE -ne 0 ]; then
  echo -e "${RED}✗ Failed to retrieve admin password from SSM${NC}"
  echo "  Parameter: ${SSM_PARAM}"
  echo "  Region: ${REGION}"
  echo "  AWS Profile: ${AWS_PROFILE:-default}"
  echo "  Error: $SSM_RESULT"
  exit 1
fi

ADMIN_PASS="$SSM_RESULT"

if [ -z "$ADMIN_PASS" ] || [ "$ADMIN_PASS" = "" ]; then
  echo -e "${RED}✗ Admin password is empty${NC}"
  exit 1
fi

echo -e "${GREEN}  ✓ Admin password retrieved from SSM${NC}"

# Parse command line arguments for optional gateway URL
GATEWAY_URL=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --gateway-url)
      GATEWAY_URL="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [--gateway-url <url>]"
      exit 1
      ;;
  esac
done

# If gateway URL not provided, use placeholder
if [ -z "$GATEWAY_URL" ]; then
  GATEWAY_URL="https://your-mcp-gateway.example.com/mcp"
  echo -e "${YELLOW}  ⚠ Gateway URL not provided, using placeholder${NC}"
  echo -e "    Rerun with: $0 --gateway-url <your-gateway-url>${NC}"
else
  echo -e "${GREEN}  ✓ Gateway URL: ${GATEWAY_URL}${NC}"
fi

# Create terraform.tfvars in mcp-oauth directory
cd "${SCRIPT_DIR}"

if [ -f "terraform.tfvars" ]; then
  echo ""
  echo -e "${YELLOW}⚠ terraform.tfvars already exists${NC}"
  echo "  Backing up to terraform.tfvars.backup"
  cp terraform.tfvars terraform.tfvars.backup
fi

echo ""
echo -e "${BLUE}Creating mcp-oauth/terraform.tfvars...${NC}"

cat > terraform.tfvars << EOF
# MCP OAuth Realm Configuration
# Auto-generated from parent Keycloak deployment
# Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

# ============================================================================
# REQUIRED: Keycloak Connection Settings (from parent deployment)
# ============================================================================

keycloak_url = "${KEYCLOAK_URL}"
keycloak_admin_username = "keycloak_admin"
keycloak_admin_password = "${ADMIN_PASS}"

# ============================================================================
# Realm Configuration
# ============================================================================

realm_name         = "mcp"
realm_display_name = "MCP OAuth Realm"

# ============================================================================
# Resource Server Configuration
# ============================================================================

# Your MCP Resource Server URI (Gateway URL)
# TODO: Update this with your actual Bedrock Agent Gateway URL
resource_server_uri = "${GATEWAY_URL}"

# ============================================================================
# Client Configuration
# ============================================================================

client_id = "mcp-spa-client"

additional_redirect_uris = [
  "http://localhost:3000/callback",
  "http://localhost:3000/",
  "http://localhost:3000/auth/callback",
]

additional_web_origins = [
  "http://localhost:3000",
  "*",
]

# ============================================================================
# Token Lifespan Configuration
# ============================================================================

access_token_lifespan = "5m"
refresh_token_lifespan = "30d"
sso_session_idle_timeout = "30m"
sso_session_max_lifespan = "10h"

# ============================================================================
# Security Settings
# ============================================================================

password_policy = "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername()"
brute_force_max_failures = 5
brute_force_failure_reset_time = 900
pkce_code_challenge_method = "S256"
ssl_required = "all"
default_signature_algorithm = "RS256"

# ============================================================================
# Client Scopes
# ============================================================================

default_scopes = [
  "openid",
  "profile",
  "email",
  "mcp:run",
  "offline_access",
]

optional_scopes = [
  "address",
  "phone",
  "microprofile-jwt",
]

# ============================================================================
# Tags
# ============================================================================

tags = {
  Environment = "$(grep '^environment' ${PARENT_DIR}/terraform.tfvars | cut -d'"' -f2)"
  Project     = "mcp-oauth"
  ManagedBy   = "terraform"
}
EOF

echo -e "${GREEN}✓ terraform.tfvars created${NC}"
echo ""

# Display configuration summary
echo "=========================================="
echo "Configuration Summary"
echo "=========================================="
echo "Keycloak URL:        ${KEYCLOAK_URL}"
echo "Admin Username:      keycloak_admin"
echo "Admin Password:      ********** (retrieved from SSM)"
echo "Gateway URL:         ${GATEWAY_URL}"
echo ""

if [ "$GATEWAY_URL" = "https://your-mcp-gateway.example.com/mcp" ]; then
  echo -e "${YELLOW}⚠ IMPORTANT: Update resource_server_uri in terraform.tfvars${NC}"
  echo "  1. Get your Bedrock Agent Gateway URL"
  echo "  2. Edit mcp-oauth/terraform.tfvars"
  echo "  3. Set: resource_server_uri = \"https://your-gateway-url/mcp\""
  echo ""
fi

echo "=========================================="
echo -e "${GREEN}✓ Initialization Complete!${NC}"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review: mcp-oauth/terraform.tfvars"
if [ "$GATEWAY_URL" = "https://your-mcp-gateway.example.com/mcp" ]; then
  echo "  2. Update: resource_server_uri with your actual Gateway URL"
  echo "  3. Deploy: cd mcp-oauth && make deploy"
else
  echo "  2. Deploy: cd mcp-oauth && make deploy"
fi
echo ""
