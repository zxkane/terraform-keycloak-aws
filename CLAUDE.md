# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an opinionated infrastructure-as-code project for deploying Keycloak (identity and access management) on AWS using Terraform. It provides a complete, production-ready setup with batteries-included networking, container orchestration, and database configuration.

Current Keycloak version: **26.4.4** (upgraded from 24.0.1)

## Key Commands

### Environment Management
```bash
# Create new environment
cd environments
./mkenv -e <env_name>
cd <env_name>
make all

# Update existing environment
cd environments/<env_name>
make update

# Destroy environment
make destroy

# Build and deploy container
cd build
make all ENV=<env_name>

# Build container only
make build ENV=<env_name>

# Deploy container only
make deploy ENV=<env_name>
```

### Database Operations
```bash
# Backup database
cd db
./dump.sh

# Restore database
./restore.sh
```

## Architecture Overview

### Core Components
- **Keycloak Application**: Containerized Keycloak running on ECS Fargate with Infinispan clustering via JDBC_PING
- **Database**: Aurora PostgreSQL cluster (minimum version 13 for Keycloak 26.4.4)
- **Load Balancing**: Application Load Balancer (ALB) with TLS termination
- **Networking**: Custom VPC with public/private subnets across 2+ AZs
- **Security**: Parameter Store for secrets, encryption everywhere by default

### Key Configuration Files
- `/build/keycloak/Dockerfile` - Container build configuration (Keycloak 26.4.4)
- `/build/keycloak/cache-ispn-jdbc-ping.xml` - Infinispan clustering configuration
- `/modules/keycloak/templates/container_definition.json` - ECS task definition template
- `/environments/template/terraform.tfvars` - Environment configuration template

### Environment Variables (Keycloak Configuration)
Critical environment variables in container_definition.json:
- `KC_DB=postgres` - Database type
- `KC_DB_URL=jdbc:postgresql://${db_addr}:5432/keycloak` - Database connection
- `KC_PROXY_HEADERS=xforwarded` - Proxy configuration (replaced KC_PROXY=edge)
- `KC_HOSTNAME_PATH=/auth` and `KC_HTTP_RELATIVE_PATH=/auth` - Path configuration
- `KC_LOG_LEVEL=INFO,org.infinispan:ERROR,org.jgroups:ERROR` - Logging
- `KC_METRICS_ENABLED=true` and `KC_HEALTH_ENABLED=true` - Monitoring

## Keycloak 26.4.4 Upgrade Notes

### Breaking Changes Handled
1. **Proxy Configuration**: Updated from `KC_PROXY=edge` to `KC_PROXY_HEADERS=xforwarded`
2. **Database Requirements**: PostgreSQL minimum version is now 13
3. **Path Normalization**: HTTP requests with `..` or `//` now return 400 by default
4. **Session Format**: Internal client session representation changed - upgrade all cluster nodes simultaneously

### New Configuration Options
- `KC_DB_POOL_MAX_LIFETIME` - PostgreSQL connection pool max lifetime (7h 50m default)
- `HTTP_ACCEPT_NON_NORMALIZED_PATHS` - Set to `true` if clients send non-normalized paths

### Monitoring Considerations
- Health check endpoint: `/health`
- Metrics endpoint: `/metrics`
- Management port: 9990
- Clustering port: 7800 (JDBC_PING)

## Development Guidelines

### When Modifying Infrastructure
1. Always backup database before major changes: `cd db && ./dump.sh`
2. Test in non-production environment first
3. Update both container_definition.json and any related Terraform variables
4. Verify Keycloak version compatibility when changing configuration

### When Updating Keycloak Version
1. Check official Keycloak upgrade guide for breaking changes
2. Update version in both Dockerfile stages (builder and runtime)
3. Review environment variables for deprecated options
4. Test database migration in staging environment
5. Plan for zero-downtime rolling upgrade

### Security Considerations
- All traffic encrypted by default (ALB, RDS, ECR, S3)
- Parameter Store used for all secrets
- Private subnets for containers and database
- TLS termination at ALB with ACM certificates

## Common Issues and Solutions

### Path Redirect Issue
Keycloak 18+ no longer automatically redirects from `/` to `/auth`. Users must access via `<domain>/auth` directly.

### Target Group Load Balancer Error
Rare issue during deployment - re-run `make all` after waiting a few minutes.

### Database Connection Issues
Ensure Aurora PostgreSQL version ≥ 13 for Keycloak 26.4.4 compatibility.

## Dependencies

### Terraform Modules (from cloudposse)
- terraform-aws-tfstate-backend
- terraform-null-label
- terraform-aws-alb
- terraform-aws-ecs-alb-service-task
- terraform-aws-ecr
- terraform-aws-rds-cluster

### Keycloak Documentation References
- Keycloak Server Installation Guide
- Keycloak Upgrading Guide
- Infinispan Documentation
- JGroups JDBC_PING Documentation
## Important Deployment Note

**Initial infrastructure deployment should have `desired_count = 0` to avoid ECS service startup failures since ECR is empty.**

### Correct Deployment Sequence:

1. **Setup Infrastructure** (with zero tasks running):
   ```bash
   # terraform.tfvars should have:
   # desired_count = 0
   terraform apply
   ```

2. **Build and Push Container**:
   ```bash
   cd build
   export AWS_REGION=ap-northeast-1
   make build ENV=ap-northeast-1-prod
   make deploy ENV=ap-northeast-1-prod
   ```

3. **Scale ECS Service** (update terraform.tfvars):
   ```bash
   # terraform.tfvars: desired_count = 2
   terraform apply
   ```

This prevents:
- ECS service failing to start due to missing image
- Failed health checks from a non-existent container
- Unnecessary service error events in AWS console

## MCP OAuth Configuration

This project includes Terraform configuration for deploying MCP (Model Context Protocol) OAuth 2.0 authentication with Keycloak.

### Location

```
environments/
├── template/mcp-oauth/           # Template for new deployments
└── <env-name>/mcp-oauth/         # Environment-specific deployments
```

### Quick Deployment

```bash
cd environments/<env-name>/mcp-oauth

# Configure
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Set keycloak_admin_password and resource_server_uri

# Deploy
make deploy
```

### Key Features

- **Dynamic Client Registration (RFC 7591)**: MCP clients can self-register
- **PKCE (RFC 7636)**: All clients use PKCE with S256
- **Resource Indicators (RFC 8707)**: Audience-based authorization
- **Realm Default Scopes**: DCR clients automatically get `mcp:run` scope
- **Audience Mapper**: Automatic JWT `aud` claim injection

### Configuration Files

**Terraform Resources:**
- `mcp-realm.tf` - Realm configuration
- `mcp-scopes.tf` - Client scopes and audience mapper
- `mcp-realm-scopes.tf` - Realm default scopes (critical for DCR)
- `mcp-client.tf` - Example clients (commented out)
- `provider.tf`, `variables.tf`, `outputs.tf`

**Deployment Scripts:**
- `deploy.sh` - Integrated deployment
- `fix-allowed-scopes.sh` - Configure DCR allowed scopes
- `update-dcr-policy.sh` - Configure DCR trusted hosts
- `enable-dcr.sh` - Test DCR

### Deployment Steps

1. **Terraform Resources** (Phase 1): `terraform apply`
2. **DCR Policies** (Phase 2): `./fix-allowed-scopes.sh && ./update-dcr-policy.sh`
3. **Verify** (Phase 3): `./enable-dcr.sh`

Or use: `make deploy` (runs all phases automatically)

### MCP Client Integration

```bash
# Add MCP server
claude mcp add --transport http <name> <gateway-url>

# Authenticate
> /mcp
```

MCP clients will:
1. Discover Authorization Server via metadata
2. Register via DCR (automatically gets `mcp:run` scope)
3. Use PKCE for authorization
4. Receive JWT with correct `aud` claim
5. Connect to MCP gateway successfully

### Important Notes

**Terraform Provider Limitation:**
- Cannot manage Client Registration Policies
- Must use provided scripts for DCR configuration
- All scripts are version-controlled and idempotent

**Critical Configuration:**
- `mcp:run` MUST be in Realm default scopes (configured in `mcp-realm-scopes.tf`)
- Audience mapper MUST be attached to `mcp:run` scope (configured in `mcp-scopes.tf`)
- DCR policies MUST allow `mcp:run` scope (configured via `fix-allowed-scopes.sh`)

### Documentation

See `environments/template/mcp-oauth/README.md` and `docs/` directory for:
- Detailed deployment guide
- Script execution order
- Terraform limitations
- Troubleshooting guide
- MCP specification compliance

### Troubleshooting

**MCP client auth succeeds but connection fails:**
1. Check client has `mcp:run` scope (Admin Console)
2. Verify token `aud` claim matches gateway URL
3. Recreate client connection (will get updated default scopes)

**DCR fails:**
1. Run `./fix-allowed-scopes.sh` (add `mcp:run` to allowed scopes)
2. Run `./update-dcr-policy.sh` (configure trusted hosts)
3. Run `./enable-dcr.sh` (verify)
