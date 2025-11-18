# MCP OAuth Realm - Terraform Configuration

Terraform configuration for deploying a Model Context Protocol (MCP) compliant OAuth 2.0 / OpenID Connect realm in Keycloak.

## Overview

This configuration creates a complete MCP OAuth realm that supports:

- ✅ **OAuth 2.0 Authorization Code Flow** with PKCE (S256)
- ✅ **Dynamic Client Registration** (RFC 7591) - clients can self-register
- ✅ **Resource Indicators** (RFC 8707) - audience-based authorization
- ✅ **Standard OIDC Scopes** - openid, profile, email
- ✅ **Custom MCP Scope** - `mcp:run` for MCP-specific permissions
- ✅ **JWT Tokens** with required claims (iss, aud, sub, exp, iat, scope)
- ✅ **Enhanced Security** - password policies, brute force protection, SSL required

## Quick Start

### Prerequisites

- Terraform >= 1.0
- Keycloak >= 18.0 (Quarkus-based recommended)
- Keycloak admin credentials
- MCP Resource Server URL (your MCP gateway)

### One-Command Deployment

```bash
# 1. Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set keycloak_admin_password and resource_server_uri

# 2. Deploy
make deploy
```

This will:
1. Initialize Terraform
2. Apply Terraform resources (Realm, Scopes, Clients)
3. Configure Client Registration Policies (via REST API)
4. Test Dynamic Client Registration
5. Display usage instructions

## Configuration Files

### Terraform Resources (IaC)

| File | Purpose |
|------|---------|
| `provider.tf` | Keycloak Terraform Provider configuration |
| `mcp-realm.tf` | Realm definition with security settings |
| `mcp-scopes.tf` | Client scopes and audience protocol mapper |
| `mcp-realm-scopes.tf` | **Realm default scopes** - Critical for DCR |
| `mcp-client.tf` | Pre-configured client examples (optional) |
| `variables.tf` | Configuration variables |
| `outputs.tf` | Endpoint URLs and configuration outputs |

### Deployment Scripts

| Script | Purpose | When to Run |
|--------|---------|-------------|
| `deploy.sh` | Integrated deployment (Terraform + Policies) | Initial deployment |
| `Makefile` | Simplified commands | All operations |
| `fix-allowed-scopes.sh` | Configure DCR allowed scopes | After Terraform apply |
| `update-dcr-policy.sh` | Configure DCR trusted hosts | After Terraform apply |
| `enable-dcr.sh` | Test DCR endpoint | Verify deployment |

### Test Scripts

| Script | Purpose |
|--------|---------|
| `test-dcr-full-flow.sh` | Complete DCR + OAuth + MCP protocol test |
| `test-oauth-flow.sh` | OAuth + PKCE flow test |
| `quick-test.sh` | Quick token and gateway validation |

## Deployment Architecture

### Two-Phase Deployment

#### Phase 1: Terraform Resources

Creates:

1. **Realm Configuration**
   - Realm with security policies
   - Token lifespans (access: 5min, refresh: 30days)
   - Password policy, brute force protection
   - SSL enforcement

2. **Client Scopes**
   - `mcp:run` - Custom MCP scope
   - **Audience Mapper** - Injects gateway URL into JWT `aud` claim

3. **Realm Default Scopes** ← **Critical**
   - Sets `mcp:run` as default scope
   - ALL new clients automatically inherit it
   - Ensures DCR clients get audience mapper

4. **Example Clients** (commented out by default)
   - SPA client example
   - Can be customized/uncommented as needed

#### Phase 2: Client Registration Policies (REST API)

**Why scripts?** Terraform Provider limitation - cannot manage Client Registration Policies.

Configures:
- Allowed Client Scopes (must include `mcp:run`)
- Trusted Hosts (controls DCR access)

## Step-by-Step Deployment

### Method 1: Integrated (Recommended)

```bash
make deploy
```

### Method 2: Manual Steps

```bash
# Phase 1: Terraform Resources
terraform init
terraform apply

# Phase 2: Create Users (Required for testing)
# Login to Admin Console and create at least one user
# See "Creating Users" section below for details

# Phase 3: DCR Policies
./fix-allowed-scopes.sh
./update-dcr-policy.sh

# Phase 4: Verify
./enable-dcr.sh
```

### Script Execution Order

**Important:** Order matters!

```
1. terraform init
2. terraform apply          # Creates realm, scopes, default scopes
3. [Create users]           # Via Admin Console - Required for OAuth login
4. fix-allowed-scopes.sh    # Adds mcp:run to DCR allowed scopes
5. update-dcr-policy.sh     # Configures trusted hosts
6. enable-dcr.sh            # Tests DCR (optional)
```

## Configuration

### Required Variables

Edit `terraform.tfvars`:

```hcl
keycloak_admin_password = "your-secure-password"
resource_server_uri = "https://your-gateway.example.com/mcp"
keycloak_url = "https://keycloak.example.com/auth"
keycloak_admin_username = "admin"
```

See `terraform.tfvars.example` for all options.

## Creating Users

### Why Users Are Required

After deploying the realm, you must create at least one user to test OAuth authentication flows. Without users, MCP clients cannot complete the login process.

### Method 1: Via Keycloak Admin Console (Recommended)

```bash
# 1. Login to Keycloak Admin Console
# URL: https://your-keycloak-url/auth/admin
# Username: admin (or your configured admin username)
# Password: (from terraform.tfvars)
```

**Steps:**
1. Select Realm: **mcp** (top-left dropdown)
2. Click **Users** in left menu
3. Click **Add user** button
4. Fill in user details:
   - **Username**: `testuser` (required)
   - **Email**: `test@example.com` (optional but recommended)
   - **First name**: `Test`
   - **Last name**: `User`
   - **Email Verified**: ON (to skip email verification)
5. Click **Save**
6. Go to **Credentials** tab
7. Click **Set password**
8. Enter password (e.g., `Test123!@#`)
9. Set **Temporary**: OFF (so user doesn't need to change password on first login)
10. Click **Save**

### Method 2: Via Terraform (Optional)

Add to your Terraform configuration (create a new file `users.tf`):

```hcl
# Example user for testing
resource "keycloak_user" "test_user" {
  realm_id   = keycloak_realm.mcp.id
  username   = "testuser"
  enabled    = true

  email          = "test@example.com"
  email_verified = true
  first_name     = "Test"
  last_name      = "User"

  initial_password {
    value     = "Test123!@#"  # Change this!
    temporary = false
  }
}
```

Then run: `terraform apply`

**Note**: Hardcoding passwords in Terraform is not recommended for production. Use Keycloak Admin Console or external identity providers for production environments.

### Method 3: Via REST API (Advanced)

```bash
# Get admin token
ADMIN_TOKEN=$(curl -s -X POST \
  "https://your-keycloak-url/auth/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=your-admin-password" \
  | jq -r '.access_token')

# Create user
curl -X POST \
  "https://your-keycloak-url/auth/admin/realms/mcp/users" \
  -H "Authorization: Bearer ${ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "enabled": true,
    "emailVerified": true,
    "email": "test@example.com",
    "firstName": "Test",
    "lastName": "User",
    "credentials": [{
      "type": "password",
      "value": "Test123!@#",
      "temporary": false
    }]
  }'
```

### Verifying User Creation

Test login with the created user:

```bash
# Test password grant (for verification only)
curl -X POST \
  "https://your-keycloak-url/auth/realms/mcp/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=mcp-debug-test" \
  -d "username=testuser" \
  -d "password=Test123!@#" \
  -d "scope=openid profile email mcp:run"
```

If successful, returns access_token, refresh_token, and id_token.

## MCP Client Integration

### Adding MCP Server (e.g., Claude Code)

```bash
claude mcp add --transport http <name> <gateway-url>
```

Then authenticate: `> /mcp`

### How It Works

1. **Discovery**: Client finds Authorization Server
2. **DCR**: Registers new OAuth client
   - **Auto-gets `mcp:run` scope** (realm default)
   - **Inherits audience mapper**
3. **Authorization**: PKCE + resource parameter
4. **Token**: JWT with correct `aud` claim
5. **Gateway**: Validates and connects

## Key Endpoints

After deployment (replace with your Keycloak URL):

- Discovery: `https://keycloak.example.com/auth/realms/mcp/.well-known/openid-configuration`
- Authorization: `https://keycloak.example.com/auth/realms/mcp/protocol/openid-connect/auth`
- Token: `https://keycloak.example.com/auth/realms/mcp/protocol/openid-connect/token`
- DCR: `https://keycloak.example.com/auth/realms/mcp/clients-registrations/openid-connect`
- JWKS: `https://keycloak.example.com/auth/realms/mcp/protocol/openid-connect/certs`

View all: `terraform output`

## Makefile Commands

```bash
make help      # Show commands
make init      # Initialize
make plan      # Preview changes
make apply     # Apply Terraform only
make deploy    # Full deployment
make test      # Test DCR
make destroy   # Destroy resources
make clean     # Clean cache
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Host not trusted" | `./update-dcr-policy.sh` |
| "Not permitted to use clientScope" | `./fix-allowed-scopes.sh` |
| Auth succeeds but connection fails | Verify `mcp:run` scope; recreate client |
| 502 Bad Gateway | Wait for Keycloak recovery; retry |

## Important Notes

### Terraform Provider Limitations

The Keycloak Terraform Provider **cannot manage Client Registration Policies**:
- ✅ Terraform manages: Realms, Clients, Scopes, Protocol Mappers
- ❌ Terraform cannot manage: Trusted Hosts, Allowed Client Scopes for DCR

**Solution**: Use provided shell scripts (`fix-allowed-scopes.sh`, `update-dcr-policy.sh`) to configure DCR policies via Keycloak Admin REST API. These scripts are version-controlled and idempotent.

### Critical Configuration for MCP Clients

**Why `mcp:run` must be a realm default scope:**

When MCP clients (like Claude Code) use Dynamic Client Registration:
1. Client registers dynamically
2. **Must receive `mcp:run` scope** (configured in `mcp-realm-scopes.tf`)
3. Inherits audience mapper from `mcp:run` scope
4. Token includes correct `aud` claim
5. Gateway validates and accepts

Without `mcp:run` as default → DCR clients missing scope → No audience → Gateway rejects (401)

## MCP Specification Compliance

| RFC | Status |
|-----|--------|
| RFC 7591 (DCR) | ✅ Complete |
| RFC 7636 (PKCE) | ✅ Complete |
| RFC 8414 (AS Metadata) | ✅ Complete |
| RFC 8707 (Resource Indicators) | ✅ Complete |
| RFC 9728 (Protected Resource) | ⚠️ Gateway-dependent |

## License

See project LICENSE file.
