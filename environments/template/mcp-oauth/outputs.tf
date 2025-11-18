# MCP OAuth Configuration Outputs
# These outputs provide essential information for integrating with MCP clients

output "realm_name" {
  description = "Name of the MCP OAuth realm"
  value       = keycloak_realm.mcp.realm
}

output "realm_id" {
  description = "ID of the MCP OAuth realm"
  value       = keycloak_realm.mcp.id
}

output "client_id" {
  description = "Client ID for the MCP SPA client"
  value       = keycloak_openid_client.mcp_spa_client.client_id
}

output "client_name" {
  description = "Display name of the MCP SPA client"
  value       = keycloak_openid_client.mcp_spa_client.name
}

# Keycloak Endpoints (construct URLs from realm info)
output "issuer_url" {
  description = "OAuth 2.0 Issuer URL"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}"
}

output "authorization_endpoint" {
  description = "OAuth 2.0 Authorization Endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/auth"
}

output "token_endpoint" {
  description = "OAuth 2.0 Token Endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/token"
}

output "userinfo_endpoint" {
  description = "OpenID Connect UserInfo Endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/userinfo"
}

output "jwks_uri" {
  description = "JSON Web Key Set URI for token signature validation"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/certs"
}

output "end_session_endpoint" {
  description = "OpenID Connect End Session Endpoint (logout)"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/logout"
}

output "check_session_iframe" {
  description = "OpenID Connect Check Session iFrame (for session management)"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/login-status-iframe.html"
}

# Discovery endpoints
output "openid_configuration_endpoint" {
  description = "OpenID Connect Discovery Endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/.well-known/openid-configuration"
}

output "oauth_authorization_server_metadata_endpoint" {
  description = "OAuth 2.0 Authorization Server Metadata Endpoint (RFC 8414)"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/.well-known/oauth-authorization-server"
}

# Resource Server Metadata endpoint for Protected Resource (RFC 9728)
# Note: This endpoint is for the Resource Server to advertise its capabilities
output "protected_resource_metadata_endpoint" {
  description = "Protected Resource Metadata Endpoint (RFC 9728) - Configure this on the Resource Server"
  value       = "${var.resource_server_uri}/.well-known/oauth-protected-resource"
}

# Dynamic Client Registration endpoints
output "client_registration_endpoint" {
  description = "OAuth 2.0 Dynamic Client Registration Endpoint (RFC 7591)"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/clients-registrations/openid-connect"
}

output "client_registration_policy_endpoint" {
  description = "Client Registration Policy Endpoint"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/client-registration-policy/providers"

}

# PKCE Configuration Information
output "pkce_code_challenge_method" {
  description = "PKCE Challenge Method (S256 or plain)"
  value       = keycloak_openid_client.mcp_spa_client.pkce_code_challenge_method
}

output "pkce_supported" {
  description = "Indicates if PKCE is supported and enabled"
  value       = true
}

# Token Lifespan Information
output "access_token_lifespan" {
  description = "Access token lifespan (minutes)"
  value       = keycloak_realm.mcp.access_token_lifespan
}

output "refresh_token_lifespan" {
  description = "Refresh token lifespan"
  value       = var.refresh_token_lifespan
}

# Security Information
output "ssl_required" {
  description = "SSL requirement setting"
  value       = keycloak_realm.mcp.ssl_required
}

output "password_policy" {
  description = "Realm password policy"
  value       = keycloak_realm.mcp.password_policy
}

# Client Configuration Details
output "valid_redirect_uris" {
  description = "Valid redirect URIs for the SPA client"
  value       = keycloak_openid_client.mcp_spa_client.valid_redirect_uris
}

output "web_origins" {
  description = "Allowed web origins (CORS)"
  value       = keycloak_openid_client.mcp_spa_client.web_origins
}

# Default and Optional Scopes
output "default_scopes" {
  description = "Default scopes assigned to the client"
  value       = keycloak_openid_client_default_scopes.mcp_client_default_scopes.default_scopes
}

output "optional_scopes" {
  description = "Optional scopes (require user consent)"
  value       = keycloak_openid_client_optional_scopes.mcp_client_optional_scopes.optional_scopes
}

# Resource Server Information
output "resource_server_uri" {
  description = "MCP Resource Server URI (audience)"
  value       = var.resource_server_uri
}

# Realm Information
output "realm_enabled" {
  description = "Indicates if the realm is enabled"
  value       = keycloak_realm.mcp.enabled
}

output "realm_display_name" {
  description = "Realm display name"
  value       = keycloak_realm.mcp.display_name
}

# Keycloak Version Information
# Note: These would require data sources to fetch actual Keycloak version info
# output "keycloak_version" {
#   description = "Keycloak server version"
#   value       = data.keycloak_server_info.server_info.version
# }

# Example MCP Client Integration Information
output "mcp_integration_example" {
  description = "Example MCP client configuration (JSON format)"
  value = jsonencode({
    realm                  = keycloak_realm.mcp.realm,
    client_id              = keycloak_openid_client.mcp_spa_client.client_id,
    resource_server_uri    = var.resource_server_uri,
    authorization_endpoint = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/auth",
    token_endpoint         = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/token",
    jwks_uri               = "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/certs",
    supported_scopes       = keycloak_openid_client_default_scopes.mcp_client_default_scopes.default_scopes,
    pkce_method            = keycloak_openid_client.mcp_spa_client.pkce_code_challenge_method,
    dcr_enabled            = true,
  })
}

# Usage Instructions
output "usage_instructions" {
  description = "Usage instructions for the MCP OAuth Realm"
  value = <<EOF

MCP OAuth Realm Configuration Complete!
=======================================

Realm: ${keycloak_realm.mcp.realm}
Client ID: ${keycloak_openid_client.mcp_spa_client.client_id}

Keycloak URLs:
- OpenID Configuration: ${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/.well-known/openid-configuration
- Authorization: ${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/auth
- Token: ${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/token
- JWKS: ${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/protocol/openid-connect/certs

Dynamic Client Registration (RFC 7591):
- Endpoint: ${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}/clients-registrations/openid-connect
- Method: POST
- Content-Type: application/json

MCP Client Configuration:
- Use Authorization Code flow with PKCE (S256)
- Set audience to: ${var.resource_server_uri}
- Request scopes: openid profile email mcp:run offline_access

Resource Server Metadata (RFC 9728):
Configure this on your Resource Server at: ${var.resource_server_uri}/.well-known/oauth-protected-resource

Example:
{
  "issuer": "${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}",
  "resource": "${var.resource_server_uri}",
  "authorization_servers": ["${var.keycloak_url}/realms/${keycloak_realm.mcp.realm}"],
  "scopes_supported": ["mcp:run", "openid", "profile", "email"]
}

For more information, see: https://github.com/keycloak/terraform-provider-keycloak

EOF
}
