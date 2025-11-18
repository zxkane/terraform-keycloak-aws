# MCP OAuth Client Configuration
# SPA (Single Page Application) client with PKCE support
# This client type is suitable for browser-based applications

resource "keycloak_openid_client" "mcp_spa_client" {
  realm_id  = keycloak_realm.mcp.id
  client_id = var.client_id

  name        = "MCP SPA Client"
  description = "MCP Single Page Application client with PKCE support"

  # Public client (no client secret needed)
  access_type = "PUBLIC"

  # Enable standard flow (Authorization Code flow)
  standard_flow_enabled = true

  # Enable implicit flow (disabled for MCP compliance)
  implicit_flow_enabled = false

  # Enable direct access grants (Resource Owner Password Credentials - disabled for MCP)
  direct_access_grants_enabled = false

  # Enable service accounts (disabled for SPA)
  service_accounts_enabled = false

  # Authorization Code Flow settings
  # Authorization code flow with PKCE (PKCE is configured separately)
  valid_redirect_uris = concat(
    [var.resource_server_uri],
    var.additional_redirect_uris
  )

  # Web origins for CORS (allow resource server domain)
  web_origins = concat(
    [var.resource_server_uri],
    var.additional_web_origins
  )

  root_url = var.resource_server_uri

  # PKCE Configuration - CRITICAL for MCP compliance
  # PKCE (Proof Key for Code Exchange) with S256 challenge method
  pkce_code_challenge_method = "S256"

  # OAuth 2.0 settings
  oauth2_device_authorization_grant_enabled = false  # Disable device flow (not needed for MCP SPA)
  oauth2_device_polling_interval              = 5

  # OpenID Connect settings
  # login_theme = "keycloak"

  # JWT settings
  use_refresh_tokens                = true
  backchannel_logout_session_required = false

  # Subject settings
  full_scope_allowed = true  # Allow full scope if no scope parameter is sent

  # Front-channel logout (optional)
  frontchannel_logout_enabled = false

  # Client authentication (not applicable for public clients)
  client_authenticator_type = "client-secret"

  # Depends on realm creation
  depends_on = [keycloak_realm.mcp]
}

# Assign default scopes to the SPA client
resource "keycloak_openid_client_default_scopes" "mcp_client_default_scopes" {
  realm_id  = keycloak_realm.mcp.id
  client_id = keycloak_openid_client.mcp_spa_client.id

  default_scopes = [
    "openid",       # OpenID Connect scope
    "profile",      # Profile information
    "email",        # Email information
    "mcp:run",      # MCP-specific scope
    "offline_access" # Allow refresh tokens
  ]
}

# Assign optional scopes (requires user consent)
resource "keycloak_openid_client_optional_scopes" "mcp_client_optional_scopes" {
  realm_id  = keycloak_realm.mcp.id
  client_id = keycloak_openid_client.mcp_spa_client.id

  optional_scopes = [
    "address",         # User address
    "phone",          # Phone number
    "microprofile-jwt" # MicroProfile JWT token
  ]
}

# Optional: Advanced Client Configuration
# Uncomment if you need additional security settings

# resource "keycloak_openid_client_permission" "mcp_client_permission" {
#   realm_id  = keycloak_realm.mcp.id
#   client_id = keycloak_openid_client.mcp_spa_client.id

#   policy_id = keycloak_openid_client_policy.mcp_client_policy.id
# }

# resource "keycloak_openid_client_policy" "mcp_client_policy" {
#   realm_id           = keycloak_realm.mcp.id
#   name               = "mcp-client-policy"
#   description        = "Policy for MCP client permissions"
#   decision_strategy  = "UNANIMOUS"
#   logic              = "POSITIVE"
#   type               = "client"
#   clients = [
#     keycloak_openid_client.mcp_spa_client.id
#   ]
# }

# Example: Create additional clients if needed (Machine-to-Machine)

# resource "keycloak_openid_client" "mcp_m2m_client" {
#   realm_id  = keycloak_realm.mcp.id
#   client_id = "mcp-m2m-client"

#   name        = "MCP M2M Client"
#   description = "MCP Machine-to-Machine client for service-to-service communication"

#   # Confidential client (requires client secret)
#   access_type = "CONFIDENTIAL"

#   # Enable service accounts (for client credentials flow)
#   service_accounts_enabled = true

#   # Enable client credentials flow
#   standard_flow_enabled = false
#   direct_access_grants_enabled = false
#   implicit_flow_enabled = false

#   # Client authentication
#   client_secret = var.m2m_client_secret

#   # Scopes
#   full_scope_allowed = true

#   depends_on = [keycloak_realm.mcp]
# }

# Example: Web Application client (Confidential with Authorization Code flow)

# resource "keycloak_openid_client" "mcp_web_client" {
#   realm_id  = keycloak_realm.mcp.id
#   client_id = "mcp-web-client"

#   name        = "MCP Web Client"
#   description = "MCP Web Application client with Authorization Code flow"

#   # Confidential client
#   access_type = "CONFIDENTIAL"

#   # Enable standard flow (Authorization Code flow)
#   standard_flow_enabled = true

#   # PKCE (can be enabled but not required for confidential clients)
#   pkce_code_challenge_method = "S256"

#   # Redirect URIs
#   valid_redirect_uris = concat(
#     [var.resource_server_uri],
#     ["${var.resource_server_uri}/callback"],
#     var.additional_redirect_uris
#   )

#   # Client secret
#   client_secret = var.web_client_secret

#   # Depends on realm creation
#   depends_on = [keycloak_realm.mcp]
# }

# Optional: Pre-configured Example Client
# Note: With Dynamic Client Registration (DCR) enabled, most clients can register dynamically.
# This example client is provided for reference only.
# You can remove this if you only plan to use DCR for client registration.

# resource "keycloak_openid_client" "example_mcp_client" {
#   realm_id  = keycloak_realm.mcp.id
#   client_id = "example-mcp-client"
#
#   name        = "Example MCP Client"
#   description = "Example pre-configured client for MCP connections"
#
#   # Public client (no client secret needed)
#   access_type = "PUBLIC"
#
#   # Enable standard flow (Authorization Code flow)
#   standard_flow_enabled = true
#
#   # Disable other flows
#   implicit_flow_enabled = false
#   direct_access_grants_enabled = false
#   service_accounts_enabled = false
#
#   # PKCE Configuration - CRITICAL for security
#   pkce_code_challenge_method = "S256"
#
#   # Redirect URIs
#   valid_redirect_uris = [
#     "http://localhost:*",
#     "http://127.0.0.1:*",
#     var.resource_server_uri,
#   ]
#
#   # Web origins for CORS
#   web_origins = [
#     "http://localhost:*",
#     "http://127.0.0.1:*",
#     var.resource_server_uri,
#   ]
#
#   root_url = "http://localhost:3000"
#
#   # JWT settings
#   use_refresh_tokens = true
#   backchannel_logout_session_required = false
#
#   # Subject settings
#   full_scope_allowed = true
#
#   # Front-channel logout
#   frontchannel_logout_enabled = false
#
#   # Client authentication
#   client_authenticator_type = "client-secret"
#
#   depends_on = [keycloak_realm.mcp]
# }
#
# # Assign default scopes to example client
# resource "keycloak_openid_client_default_scopes" "example_client_default_scopes" {
#   realm_id  = keycloak_realm.mcp.id
#   client_id = keycloak_openid_client.example_mcp_client.id
#
#   default_scopes = [
#     "openid",
#     "profile",
#     "email",
#     "mcp:run",
#   ]
# }
#
# # Audience mapper for example client
# resource "keycloak_openid_hardcoded_claim_protocol_mapper" "example_client_audience_mapper" {
#   realm_id  = keycloak_realm.mcp.id
#   client_id = keycloak_openid_client.example_mcp_client.id
#   name      = "example-client-audience"
#
#   claim_name       = "aud"
#   claim_value      = var.resource_server_uri
#   claim_value_type = "String"
#   add_to_id_token     = false
#   add_to_access_token = true
#   add_to_userinfo     = false
# }
