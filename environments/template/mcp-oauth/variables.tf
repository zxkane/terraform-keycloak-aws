# MCP OAuth Configuration Variables
# These variables allow customization of the MCP Realm without modifying code

# Keycloak Connection Settings
variable "keycloak_url" {
  description = "Keycloak base URL (include /auth for Wildfly, omit for Quarkus)"
  type        = string
  default     = "https://keycloak.example.com/auth"
}

variable "keycloak_admin_username" {
  description = "Keycloak admin username"
  type        = string
  sensitive   = true
  default     = "keycloak_admin"
}

variable "keycloak_admin_password" {
  description = "Keycloak admin password"
  type        = string
  sensitive   = true
  default     = ""  # Must be provided via TF_VAR_keycloak_admin_password or -var flag
}

# Realm Configuration
variable "realm_name" {
  description = "Name of the MCP OAuth realm"
  type        = string
  default     = "mcp"
}

variable "realm_display_name" {
  description = "Display name for the MCP realm"
  type        = string
  default     = "MCP OAuth Realm"
}

# Resource Server Configuration
variable "resource_server_uri" {
  description = "MCP Resource Server URI (used for audience mapping and redirect URIs)"
  type        = string
  default     = "https://your-mcp-gateway.example.com/mcp"
}

# Client Configuration
variable "client_id" {
  description = "Client ID for the MCP SPA client"
  type        = string
  default     = "mcp-spa-client"
}

variable "client_name" {
  description = "Display name for the MCP SPA client"
  type        = string
  default     = "MCP SPA Client"
}

# Redirect and Web Origins
variable "additional_redirect_uris" {
  description = "Additional redirect URIs for the SPA client"
  type        = list(string)
  default     = [
    "http://localhost:3000/callback",
    "http://localhost:3000/",
    "http://localhost:3000/auth/callback",
  ]
}

variable "additional_web_origins" {
  description = "Additional web origins for CORS"
  type        = list(string)
  default     = [
    "http://localhost:3000",
    "*",
  ]
}

# Token Lifespan Configuration
variable "access_token_lifespan" {
  description = "Access token lifespan (format: XhYmZs)"
  type        = string
  default     = "5m"
}

variable "refresh_token_lifespan" {
  description = "Refresh token lifespan (format: XhYmZs)"
  type        = string
  default     = "30d"
}

variable "sso_session_idle_timeout" {
  description = "SSO session idle timeout (format: XhYmZs)"
  type        = string
  default     = "30m"
}

variable "sso_session_max_lifespan" {
  description = "SSO session maximum lifespan (format: XhYmZs)"
  type        = string
  default     = "10h"
}

# Security Settings
variable "password_policy" {
  description = "Password policy (Keycloak format)"
  type        = string
  default     = "length(12) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(1) and notUsername()"
}

variable "brute_force_max_failures" {
  description = "Maximum login failures before temporary lockout"
  type        = number
  default     = 5
}

variable "brute_force_failure_reset_time" {
  description = "Time in seconds before login failure counter resets"
  type        = number
  default     = 900  # 15 minutes
}

# PKCE Configuration
variable "pkce_code_challenge_method" {
  description = "PKCE challenge method (S256 or plain)"
  type        = string
  default     = "S256"
  validation {
    condition     = contains(["S256", "plain"], var.pkce_code_challenge_method)
    error_message = "PKCE challenge method must be either 'S256' or 'plain'."
  }
}

# Client Scopes
variable "default_scopes" {
  description = "Default scopes assigned to the SPA client"
  type        = list(string)
  default     = [
    "openid",
    "profile",
    "email",
    "mcp:run",
    "offline_access",
  ]
}

variable "optional_scopes" {
  description = "Optional scopes (require user consent)"
  type        = list(string)
  default     = [
    "address",
    "phone",
    "microprofile-jwt",
  ]
}

# Advanced Settings
variable "ssl_required" {
  description = "SSL requirement (none, external, all)"
  type        = string
  default     = "all"
  validation {
    condition     = contains(["none", "external", "all"], var.ssl_required)
    error_message = "SSL requirement must be 'none', 'external', or 'all'."
  }
}

variable "default_signature_algorithm" {
  description = "Default signature algorithm for tokens"
  type        = string
  default     = "RS256"
}

# SMTP Settings (optional)
variable "enable_smtp" {
  description = "Enable SMTP configuration"
  type        = bool
  default     = false
}

variable "smtp_host" {
  description = "SMTP server host"
  type        = string
  default     = "smtp.example.com"
}

variable "smtp_port" {
  description = "SMTP server port"
  type        = number
  default     = 587
}

variable "smtp_from" {
  description = "SMTP from address"
  type        = string
  default     = "noreply@example.com"
}

variable "smtp_username" {
  description = "SMTP username"
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_password" {
  description = "SMTP password"
  type        = string
  sensitive   = true
  default     = ""
}

# Tags for resources (if your Keycloak supports it)
variable "tags" {
  description = "Tags to apply to Keycloak resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "mcp-oauth"
    ManagedBy   = "terraform"
  }
}
