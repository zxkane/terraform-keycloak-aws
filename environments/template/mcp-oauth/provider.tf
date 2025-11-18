terraform {
  required_version = ">= 1.0"

  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = ">= 4.3.0"
    }
  }
}

# Keycloak Provider Configuration
# Authentication methods (choose one):

# Method 1: Using admin username/password (Recommended for initial setup)
# Variables are defined in variables.tf

provider "keycloak" {
  client_id = "admin-cli"
  username  = var.keycloak_admin_username
  password  = var.keycloak_admin_password
  url       = var.keycloak_url

  # For Quarkus-based Keycloak 18+, remove base_path
  # For Wildfly-based Keycloak, use: base_path = "/auth"
}

# Method 2: Using client credentials (Recommended for CI/CD)
# (Uncomment and configure if needed)
# variable "keycloak_client_id" {
#   description = "Keycloak client ID for provider authentication"
#   type        = string
#   sensitive   = true
# }
#
# variable "keycloak_client_secret" {
#   description = "Keycloak client secret for provider authentication"
#   type        = string
#   sensitive   = true
# }
#
# provider "keycloak" {
#   client_id     = var.keycloak_client_id
#   client_secret = var.keycloak_client_secret
#   url           = var.keycloak_url
# }

# Method 3: Using pre-provisioned token
# (Uncomment and use if you have an existing access token)
# variable "keycloak_access_token" {
#   description = "Pre-provisioned Keycloak access token"
#   type        = string
#   sensitive   = true
# }
#
# provider "keycloak" {
#   url          = var.keycloak_url
#   access_token = var.keycloak_access_token
# }
