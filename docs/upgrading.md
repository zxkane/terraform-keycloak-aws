# Upgrades

**NOTE:** Keycloak has moved from Wildfly to Quarkus. Configuration is now handled
via environment variables and `cache-ispn-jdbc-ping.xml` instead of `standalone-ha.xml`.

Always [browse the upgrade guide](https://www.keycloak.org/docs/latest/upgrading/index.html),
[read the release notes](https://www.keycloak.org/docs/latest/release_notes),
and test in a low-risk environment first.

Keycloak version upgrades are fairly painless, even across several major
versions. The configuration and database schema upgrades are automated.

## Prepare Database

Technically you don't have to do anything. When you start a new container version,
Liquibase will auto-detect the older schema and take care of everything.

To be safe, you should backup the database before upgrading. You can simply
take a RDS snapshot or (also) use the scripts in the `db` directory to dump
and restore. These are very simple at the moment, but have been tested.
They can also be used to migrate data between clusters.

Shortly after starting a new container version, you should see this message in CloudWatch:

```console
[org.keycloak.connections.jpa.updater.liquibase.LiquibaseJpaUpdaterProvider] (ServerService Thread Pool -- 64) Updating database. Using changelog META-INF/jpa-changelog-master.xml
```

## Keycloak 26.4.4 Upgrade Specifics

### Breaking Changes from 24.x to 26.4.4

1. **Proxy Configuration**: `KC_PROXY=edge` is deprecated, use `KC_PROXY_HEADERS=xforwarded`
2. **Database Requirements**: PostgreSQL minimum version is now 13
3. **Path Normalization**: HTTP requests with `..` or `//` return 400 by default
4. **Session Format**: Internal client session representation changed - upgrade all cluster nodes simultaneously

### New Configuration Options

- `KC_DB_POOL_MAX_LIFETIME`: PostgreSQL connection pool max lifetime (7h 50m default)
- `HTTP_ACCEPT_NON_NORMALIZED_PATHS`: Set to `true` if clients send non-normalized paths

### Cluster Upgrade Warning

**DO NOT run 26.4.x concurrently in a cluster with previous versions** - upgrade all nodes simultaneously due to client session format changes.

## Update Container

- Change to `build/keycloak`
- Update the Dockerfile's `FROM` line with desired version (both builder and runtime stages)
- Review environment variables in `container_definition.json` for deprecated options
- Update proxy configuration from `KC_PROXY=edge` to `KC_PROXY_HEADERS=xforwarded`
- Commit your changes

You can now deploy by running `make all ENV=<env_name>` in the build directory.
This will build the container, push to ECR and roll the service without downtime.
