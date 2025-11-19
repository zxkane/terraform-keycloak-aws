#!/usr/bin/env bash
#
# Load configuration from Terraform variables and outputs
# Source this file in other scripts: source ./load-config.sh
#

set -euo pipefail

# Get script directory (works even when sourced)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if terraform.tfvars exists
if [ ! -f "${SCRIPT_DIR}/terraform.tfvars" ]; then
  echo "Error: terraform.tfvars not found in ${SCRIPT_DIR}"
  echo "Please create terraform.tfvars from terraform.tfvars.example"
  exit 1
fi

# Parse configuration from terraform.tfvars
# This handles both quoted and unquoted values
parse_tfvar() {
  local key="$1"
  local file="${SCRIPT_DIR}/terraform.tfvars"
  grep "^${key}\s*=" "$file" | sed -E 's/.*=\s*"?([^"]*)"?.*/\1/' | tr -d '"' | xargs
}

# Load configuration
export KEYCLOAK_URL=$(parse_tfvar "keycloak_url")
export KEYCLOAK_ADMIN_USERNAME=$(parse_tfvar "keycloak_admin_username")
export KEYCLOAK_ADMIN_PASSWORD=$(parse_tfvar "keycloak_admin_password")
export REALM_NAME=$(parse_tfvar "realm_name")
export RESOURCE_SERVER_URI=$(parse_tfvar "resource_server_uri")

# Validate required variables
if [ -z "$KEYCLOAK_URL" ] || [ "$KEYCLOAK_URL" = "" ]; then
  echo "Error: keycloak_url not found in terraform.tfvars"
  exit 1
fi

if [ -z "$KEYCLOAK_ADMIN_PASSWORD" ] || [ "$KEYCLOAK_ADMIN_PASSWORD" = "" ]; then
  echo "Error: keycloak_admin_password not set in terraform.tfvars"
  echo "Please set: keycloak_admin_password = \"your-password\""
  exit 1
fi

# Set defaults if not found
: ${KEYCLOAK_ADMIN_USERNAME:="admin"}
: ${REALM_NAME:="mcp"}

# Export for use in scripts
export KEYCLOAK_URL
export KEYCLOAK_ADMIN_USERNAME
export KEYCLOAK_ADMIN_PASSWORD
export REALM_NAME
export RESOURCE_SERVER_URI

# Debug output (only if DEBUG=1)
if [ "${DEBUG:-0}" = "1" ]; then
  echo "Configuration loaded:"
  echo "  KEYCLOAK_URL: $KEYCLOAK_URL"
  echo "  KEYCLOAK_ADMIN_USERNAME: $KEYCLOAK_ADMIN_USERNAME"
  echo "  REALM_NAME: $REALM_NAME"
  echo "  RESOURCE_SERVER_URI: $RESOURCE_SERVER_URI"
fi
