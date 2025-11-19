# Contents

- [Recent Enhancements](#recent-enhancements)
- [Introduction](#introduction)
- [Prerequisites](#prerequisites)
- [Workflow](#workflow)
- [Monitoring](#monitoring)
- [Opinions](#opinions)
- [TODO](#todo)
- [Dependencies](#dependencies)
- [References](#references)
- [FAQ](#FAQ)

## Recent Enhancements

### 🚀 Keycloak 26.4.4 Upgrade (November 2024)

Major version upgrade from 24.0.1 to 26.4.4 with production-tested configuration:

- **Modern Proxy Configuration**: Updated from deprecated `KC_PROXY=edge` to `KC_PROXY_HEADERS=xforwarded`
- **Enhanced Monitoring**: Built-in health (`/auth/health`) and metrics (`/auth/metrics`) endpoints
- **Improved Health Checks**: ALB health check path updated to reliable `/auth/realms/master` endpoint
- **Database Requirements**: PostgreSQL 13+ for compatibility
- **Zero-Downtime Support**: JDBC_PING clustering for seamless upgrades

See [CLAUDE.md](CLAUDE.md) for detailed upgrade notes and breaking changes.

### 🔐 MCP OAuth 2.1 Integration (November 2024)

Complete OAuth 2.1/OIDC infrastructure for Model Context Protocol (MCP) clients:

- **Dynamic Client Registration (DCR)**: RFC 7591 compliant, enabling Claude Code, Cursor, and VS Code integration
- **Audience-Based Authorization**: RFC 8807 resource indicators with automatic JWT `aud` claim injection
- **PKCE Enforcement**: S256 code challenge for secure public client flows
- **Automated Deployment**: One-command deployment (`make deploy`) with integrated DCR policy configuration
- **Comprehensive Documentation**: Complete setup guide in [environments/template/mcp-oauth/](environments/template/mcp-oauth/)

**Key Features**:
- Realm default scopes auto-configuration (DCR clients inherit `mcp:run` scope)
- Anonymous DCR support (no trusted hosts restrictions for cursor://, vscode:// URIs)
- Audience protocol mapper for seamless gateway integration
- Complete test suite for validation

**Quick Start**:
```bash
cd environments/<env-name>/mcp-oauth
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
make deploy
```

### 🔧 Production-Ready Improvements

Recent enhancements ensure robust production deployments:

- **Health Check Reliability**: Fallback to `/auth/realms/master` prevents false negatives during startup
- **Monitoring Enabled**: `KC_HEALTH_ENABLED=true` and `KC_METRICS_ENABLED=true` by default
- **Container Optimization**: Fixed build-time vs runtime configuration consistency
- **Path Normalization**: Updated handling for HTTP requests with `..` or `//` sequences
- **Automated MCP Client Configuration**: Deploy script automatically configures Keycloak for Claude Code/Cursor/VS Code

## Introduction

**NOTE:** I spin releases for the latest Keycloak versions avoiding "dot ohs"
e.g. 15.1.1+ but not 15.1.0.

Opinionated infrastructure and deployment automation for Keycloak on AWS Fargate with MCP OAuth 2.1 authentication support.

- Batteries included (network plumbing + container build/deploy) 🚀
- MCP OAuth 2.1 compatible (DCR, PKCE, audience-based authorization) 🔐
- Tested with latest Terraform 😍
- Prefer fully-managed backing services (Fargate, Aurora, CloudWatch) 🥱
- JDBC clustering and cache replication (improved HA) 🤙

![Logical Diagram](https://raw.githubusercontent.com/deadlysyn/terraform-keycloak-aws/main/assets/keycloak.png "Logical Diagram")

**NOTE:** The diagram shows the default self-contained publicly-accessible service
leveraging the included
[network module](https://github.com/deadlysyn/terraform-keycloak-aws/tree/main/modules/network).
You can also deploy an internal service (no Internet connectivity) or public
service that uses your own network infrastructure. See
[terraform.tfvars](https://github.com/deadlysyn/terraform-keycloak-aws/blob/main/environments/template/terraform.tfvars)
for examples of how to select the right approach for your needs. When deploying
to your own network infrastructure, read over the network module to understand
how to configure network components.

Psst: [Need IaC for your Keycloak clients?](https://github.com/deadlysyn/keycloakinator)

## Prerequisites

- [aws v2 CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- Docker (container build/deploy)
- UNIX-like OS (tested on Linux and MacOS)

## Workflow

The basic workflow relies on make to reduce typing toil.
If you are just getting started, refer to
[the bootstrapping guide](https://github.com/deadlysyn/terraform-keycloak-aws/blob/main/docs/bootstrapping.md).

```console
# Create new environment
$ cd environments
$ ./mkenv -e <env_name>
$ cd <env_name>
$ make all

# Update existing environment
$ cd environments/<env_name>
$ vi terraform.tfvars # edit as needed...
$ make update

# Destroy environment
$ cd environments/<env_name>
$ make destroy
# type 'yes' to confirm

# Build Keycloak container and deploy
$ cd build
$ make all ENV=<env_name>
```

**NOTE:** Once deployed, Keycloak will be accessible via `<yourdomain>/auth`.
Due to [this breaking change](https://github.com/keycloak/keycloak/discussions/10274)
there is no longer an automatic redirect from `/` to `/auth`. Neither the provided
environment variable nor build flag restore prior behavior as expected (I consider
this a bug). I may update the ALB configuration to add this back, but have not
done so yet. I welcome feedback on preferred approaches.

## Monitoring

Since monitoring approaches vary, I've avoided codifying monitoring-specific opinions
to avoid adding cost and complexity. In combination with external synthetics and
metrics, you may want to extend this with sidecar containers to provide enhanced monitoring.
[An example of how to do that with Datadog](https://github.com/deadlysyn/terraform-keycloak-aws/blob/main/modules/keycloak/templates/container_definition_datadog.json)
is included for reference. When adding sidecars, you will need to adjust CPU and
memory reservations appropriately. For Datadog, you need to reserve an additional
256 CPU units and 512MB of memory.

## Opinions

Similar to popular frameworks, bootstrap time is reduced by encapsulating technical opinions.
This gets functional infrastructure online quickly and consistently.
However, you can easily adjust these as needed. This section calls out key
design choices.

### Don't Re-Invent the Wheel

The Keycloak module itself wraps only a few AWS Terraform primitives, preferring
trusted registry modules. Avoiding bespoke solutions where community-tested options
exist improves quality and reduces maintenance overhead.

We have contributed to many of these modules ourselves, and leverage them for
production infrastructure. We've taken the time to read the module source,
understand how they work, and reason about the choices they've made.
You should do the same. Dependencies are conveniently linked in
[References](https://github.com/deadlysyn/terraform-keycloak-aws#references).

### An Exception to Every Rule

While there are a number of modules to create AWS network resources, networking
is an exception to the re-use rule above. The provided network module
is simplistic, but adequate and easy to adjust based on your requirements.

It is meant to serve two purposes: a starting point to get new environments
online quickly, and interface documentation. Taking it's outputs as an example, you
can easily provide similar inputs via configuration from existing infrastructure or
a module of your choice.

### Encrypt Everything

Whether ALB listeners, ECR, RDS, or remote state... anything that can have encryption
enabled does by default. Aside from belief in the cypherpunk motto,
this is due to the fact Keycloak is a security service.

The one exception today is intra-VPC traffic between the ALB and ECS containers.
Fixing this so service traffic is FULLY encrypted is on the TODO list (PRs welcome).

Aside from just "turning it on", thought is being given to cert management,
workflow, etc. For example, a sidecar proxy integrated with Let's Encrypt
would be more up-front complexity but not require updating container trust
stores, worrying about renewals, etc.

### Reduce Cognitive Load

Upstream defaults are used when sensible. Settings unlikely to change in the typical
case have local defaults or are hard-coded (e.g. DB port number). The goal is to reduce
cognitive load, but these are only opinions that you can override.

The included
[standalone-ha.xml](https://github.com/deadlysyn/terraform-keycloak-aws/blob/main/build/keycloak/standalone-ha.xml)
and
[docker-entrypoint.sh](https://github.com/deadlysyn/terraform-keycloak-aws/blob/main/build/keycloak/docker-entrypoint.sh)
have been adjusted to work with ECS out of the box. These should generally suffice,
but may need adjusted based on your requirements.
You might also want to toggle different feature flags, which
are controlled in
[profile.properties](https://github.com/deadlysyn/terraform-keycloak-aws/blob/main/build/keycloak/profile.properties).

## TODO

- Terratests
- ALB -> ECS TLS
- Performance test automation + baseline
- Multi-region support
- MySQL support

## Dependencies

- https://github.com/cloudposse/terraform-aws-tfstate-backend
- https://github.com/cloudposse/terraform-null-label
- https://github.com/cloudposse/terraform-aws-alb
- https://github.com/cloudposse/terraform-aws-ecs-alb-service-task
- https://github.com/cloudposse/terraform-aws-ecr
- https://github.com/cloudposse/terraform-aws-rds-cluster

## References

- https://hub.docker.com/r/jboss/keycloak
- https://www.keycloak.org/docs/latest/server_installation/index.html
- https://www.keycloak.org/docs/latest/upgrading/index.html
- https://docs.datadoghq.com/integrations/ecs_fargate
- https://docs.datadoghq.com/integrations/faq/integration-setup-ecs-fargate
- https://docs.datadoghq.com/agent/guide/autodiscovery-with-jmx

Abandon hope all ye who enter here... :-)

- https://www.keycloak.org/docs/latest/server_installation/index.html#_clustering
- https://infinispan.org/docs/stable/index.html
- https://www.keycloak.org/2019/05/keycloak-cluster-setup.html
- https://www.keycloak.org/2019/08/keycloak-jdbc-ping
- http://jgroups.org/manual/#JDBC_PING
- https://octopus.com/blog/wildfly-jdbc-ping

## FAQ

Q: `The target group with targetGroupArn <arn> does not have an associated load balancer.`

A: This is rare, but if it happens to you just re-run `make all` (double apply), perhaps waiting a few minutes in between.

Q: How do I integrate Claude Code or other MCP clients with Keycloak?

A: See the complete setup guide in [environments/template/mcp-oauth/](environments/template/mcp-oauth/). The infrastructure supports Dynamic Client Registration (DCR) out of the box - simply copy the template to your environment, configure variables, and run `make deploy`. Claude Code will automatically discover and register with your Keycloak realm.

Q: Why is my ALB health check failing after upgrading to Keycloak 26.4.4?

A: Keycloak 26.4.4 requires `KC_HEALTH_ENABLED=true` for the `/auth/health` endpoint. The updated configuration uses `/auth/realms/master` as a reliable alternative health check path. For existing deployments, either update your Target Group health check path or redeploy with the latest container configuration that includes `KC_HEALTH_ENABLED=true`.

Q: What Keycloak version is currently supported?

A: Keycloak **26.4.4** (upgraded from 24.0.1 in November 2024). This version requires PostgreSQL 13+ and includes important security and performance improvements. See [CLAUDE.md](CLAUDE.md) for detailed upgrade notes.

Q: How do I get support?

A: Open GitHub issues. If there's a bug you know how to fix, also open a PR and link it in your issue.
