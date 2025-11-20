# Realm-Level Default and Optional Client Scopes
# These scopes are automatically assigned to ALL new clients (including DCR clients)

# Configure realm-level default scopes
# All new clients will automatically get these scopes
resource "keycloak_realm_default_client_scopes" "mcp_realm_defaults" {
  realm_id = keycloak_realm.mcp.id

  # Default scopes - automatically included in all tokens
  # Note: "openid" is not a client scope in Keycloak, it's handled at protocol level
  default_scopes = [
    "profile",      # User profile (Keycloak built-in)
    "email",        # User email (Keycloak built-in)
    "mcp:run",      # MCP operations (our custom scope) ← CRITICAL for MCP
    "roles",        # User roles (Keycloak built-in)
    "web-origins",  # CORS origins (Keycloak built-in)
    "acr",          # Authentication Context Class Reference (Keycloak built-in)
    "basic",        # Basic scope (Keycloak built-in)
  ]

  # Ensure mcp:run scope is created before assigning it as default
  depends_on = [
    keycloak_openid_client_scope.mcp_run,
  ]
}

# Configure realm-level optional scopes
# These require explicit user consent when requested
resource "keycloak_realm_optional_client_scopes" "mcp_realm_optional" {
  realm_id = keycloak_realm.mcp.id

  # Optional scopes - require user consent
  optional_scopes = [
    "address",          # User address (Keycloak built-in)
    "phone",           # Phone number (Keycloak built-in)
    "offline_access",  # Refresh tokens (Keycloak built-in)
    "microprofile-jwt", # MicroProfile JWT (Keycloak built-in)
  ]
}
