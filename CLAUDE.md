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
