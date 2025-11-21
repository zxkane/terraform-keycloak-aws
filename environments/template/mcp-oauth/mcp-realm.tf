# MCP OAuth Realm Configuration
# This realm provides OAuth 2.0 / OpenID Connect for MCP (Model Context Protocol)
# Key features: PKCE, Dynamic Client Registration, Resource Indicators support

resource "keycloak_realm" "mcp" {
  realm   = var.realm_name
  enabled = true

  # Display settings
  display_name                = "MCP OAuth Realm"
  display_name_html           = "<b>MCP</b> OAuth Realm"
  # Themes removed as they are not available on server
  # login_theme                 = "keycloak"
  # account_theme               = "keycloak"
  # admin_theme                 = "keycloak"
  # email_theme                 = "keycloak"

  # Token settings
  access_token_lifespan                     = "24h"  # 1 day for access tokens
  access_token_lifespan_for_implicit_flow   = "24h"  # 1 day for implicit flow (not used in MCP)
  sso_session_idle_timeout                  = "24h"  # 1 day idle timeout
  sso_session_max_lifespan                  = "24h"  # 1 day max session
  offline_session_idle_timeout              = "720h" # 30 days for offline sessions (720 hours)
  offline_session_max_lifespan              = "1440h" # 60 days max for offline sessions (1440 hours)

  # Security settings
  ssl_required                     = "all"  # Require SSL for all connections
  registration_allowed             = false  # Disable self-registration (use DCR instead)
  registration_email_as_username   = false
  remember_me                      = true
  verify_email                     = false
  login_with_email_allowed         = true
  duplicate_emails_allowed         = false
  reset_password_allowed           = true
  edit_username_allowed            = false

  # OAuth 2.0 / OpenID Connect settings
  access_code_lifespan             = "10m"  # 10 minutes for authorization codes
  access_code_lifespan_user_action = "10m"
  action_token_generated_by_admin_lifespan = "12h"
  action_token_generated_by_user_lifespan  = "5m"

  # OAuth 2.0 Device Authorization Grant (for future use)
  oauth2_device_code_lifespan      = "10m"
  oauth2_device_polling_interval   = 5

  # Internationalization
  internationalization {
    supported_locales = ["en"]
    default_locale    = "en"
  }

  # Security defenses
  security_defenses {
    headers {
      x_frame_options                     = "DENY"
      content_security_policy             = "frame-src 'self'; frame-ancestors 'self'; object-src 'none';"
      content_security_policy_report_only = ""
      x_content_type_options              = "nosniff"
      x_robots_tag                        = "none"
      x_xss_protection                    = "1; mode=block"
      strict_transport_security           = "max-age=31536000; includeSubDomains"
    }

    brute_force_detection {
      permanent_lockout                = false
      max_login_failures               = 5
      wait_increment_seconds           = 60
      quick_login_check_milli_seconds  = 1000
      minimum_quick_login_wait_seconds = 60
      failure_reset_time_seconds       = 900  # 15 minutes
    }
  }

  # Password policy
  # Require: minimum 12 chars, at least 1 uppercase, 1 lowercase, 1 digit, 1 special char
  password_policy = "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername()"

  # Token settings
  revoke_refresh_token = true  # Revoke refresh token on logout
  refresh_token_max_reuse = 0   # Refresh token can only be used once
  sso_session_idle_timeout_remember_me = "720h"
  sso_session_max_lifespan_remember_me = "2160h"

  # Default signature algorithm for tokens
  default_signature_algorithm = "RS256"

  # SMTP settings (optional - uncomment and configure if needed)
  # smtp_server {
  #   host     = var.smtp_host
  #   port     = var.smtp_port
  #   from     = var.smtp_from
  #   reply_to = var.smtp_reply_to
  #   auth {
  #     username = var.smtp_username
  #     password = var.smtp_password
  #   }
  #   ssl = false
  #   starttls = true
  # }

  # WebAuthn settings (optional - for passwordless auth)
  # web_authn_policy {
  #   relying_party_entity_name = "MCP OAuth"
  #   relying_party_id           = var.keycloak_domain
  #   signature_algorithms       = ["ES256", "RS256"]
  # }

  # Event listeners (for auditing)
  # events_enabled                    = true
  # events_expiration                 = "90d"
  # admin_events_enabled               = true
  # admin_events_details_enabled       = true

  # Login authentication flow
  # Uses the default browser flow (suitable for most use cases)
  # Note: PKCE is enabled at client level, not realm level
}

# Dynamic Client Registration (DCR) Notes:
# DCR is enabled by default in Keycloak and available at:
# POST /realms/mcp/clients-registrations/openid-connect
# No additional configuration needed - clients can register dynamically using RFC 7591

# Optional: If you need custom authentication flows, uncomment below
# resource "keycloak_authentication_flow" "mcp_custom_flow" {
#   realm_id    = keycloak_realm.mcp.id
#   alias       = "mcp-custom-flow"
#   description = "Custom authentication flow for MCP"
# }
#
# resource "keycloak_authentication_execution" "mcp_custom_execution" {
#   realm_id          = keycloak_realm.mcp.id
#   parent_flow_alias = keycloak_authentication_flow.mcp_custom_flow.alias
#   authenticator     = "auth-username-password-form"
#   requirement       = "REQUIRED"
# }
