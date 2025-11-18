# MCP OAuth Scopes and Protocol Mappers
# This file defines client scopes, mappers, and claims for MCP OAuth compliance

# Create MCP-specific scope
resource "keycloak_openid_client_scope" "mcp_run" {
  realm_id                = keycloak_realm.mcp.id
  name                    = "mcp:run"
  description             = "MCP Run Scope - Required for MCP operations"
  include_in_token_scope  = true
  consent_screen_text     = "Allow access to MCP resources"
  gui_order               = 1
}

# CRITICAL: Add audience mapper to mcp:run scope
# This ensures ALL clients (including DCR-created clients) get the correct audience claim
resource "keycloak_openid_hardcoded_claim_protocol_mapper" "mcp_run_audience_mapper" {
  realm_id        = keycloak_realm.mcp.id
  client_scope_id = keycloak_openid_client_scope.mcp_run.id
  name            = "mcp-audience"

  claim_name       = "aud"
  claim_value      = var.resource_server_uri
  claim_value_type = "String"
  add_to_id_token     = false
  add_to_access_token = true
  add_to_userinfo     = false
}

# Reference standard OpenID Connect scopes (profile, email)
# These are built-in Keycloak scopes, so we use data sources instead of creating them
data "keycloak_openid_client_scope" "profile" {
  realm_id = keycloak_realm.mcp.id
  name     = "profile"
}

data "keycloak_openid_client_scope" "email" {
  realm_id = keycloak_realm.mcp.id
  name     = "email"
}

# Built-in scope mappers (email, email_verified, username, full_name) are already
# provided by Keycloak's default email and profile scopes, so we don't need to recreate them.
# The email and profile scopes already include these mappers by default.

# User ID mapper (sub claim is handled automatically, this is additional)
resource "keycloak_openid_user_property_protocol_mapper" "user_id_mapper" {
  realm_id        = keycloak_realm.mcp.id
  client_scope_id = data.keycloak_openid_client_scope.profile.id
  name            = "user id"

  user_property       = "id"
  claim_name          = "user_id"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Realm roles mapper - adds user's realm roles to token
resource "keycloak_openid_user_realm_role_protocol_mapper" "realm_roles_mapper" {
  realm_id        = keycloak_realm.mcp.id
  client_scope_id = data.keycloak_openid_client_scope.profile.id
  name            = "realm roles"

  claim_name          = "realm_access.roles"
  claim_value_type    = "String"
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Group membership mapper
resource "keycloak_openid_group_membership_protocol_mapper" "group_membership_mapper" {
  realm_id        = keycloak_realm.mcp.id
  client_scope_id = data.keycloak_openid_client_scope.profile.id
  name            = "groups"

  claim_name          = "groups"
  full_path           = false
  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# CRITICAL FIX: Custom Audience Mapper for Resource Indicators (RFC 8707)
# These mappers already exist from previous deployment
# Note: If you need to recreate them, you must first import them with:
# terraform import keycloak_openid_hardcoded_claim_protocol_mapper.audience_claim_mapper mcp/CLIENT_ID/MAPPER_ID

# Audience claim mapper - sets aud claim to resource server URI
# resource "keycloak_openid_hardcoded_claim_protocol_mapper" "audience_claim_mapper" {
#   realm_id        = keycloak_realm.mcp.id
#   client_id       = keycloak_openid_client.mcp_spa_client.id
#   name            = "audience-claim"
#
#   claim_name       = "aud"
#   claim_value      = var.resource_server_uri
#   claim_value_type = "String"
#   add_to_id_token  = false
#   add_to_access_token = true
#   add_to_userinfo  = false
# }

# MCP version mapper - adds MCP version to token
# resource "keycloak_openid_hardcoded_claim_protocol_mapper" "mcp_version_mapper" {
#   realm_id        = keycloak_realm.mcp.id
#   client_id       = keycloak_openid_client.mcp_spa_client.id
#   name            = "mcp-version"
#
#   claim_name       = "mcp_version"
#   claim_value      = "1.0"
#   claim_value_type = "String"
#   add_to_id_token  = true
#   add_to_access_token = true
#   add_to_userinfo  = false
# }

# Scope claim mapper - Note: scope is automatically included in tokens
# resource "keycloak_openid_hardcoded_claim_protocol_mapper" "scope_claim_mapper" {
#   realm_id        = keycloak_realm.mcp.id
#   client_id       = keycloak_openid_client.mcp_spa_client.id
#   name            = "scope-claim"
#
#   claim_name       = "scope"
#   claim_value      = "mcp:run profile email"
#   claim_value_type = "String"
#   add_to_id_token  = true
#   add_to_access_token = true
#   add_to_userinfo  = false
# }
