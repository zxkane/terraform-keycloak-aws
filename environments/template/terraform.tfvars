#
# !!! This section requires the most attention. !!!
#
# Choose ONE network option, uncomment and customize variables...
#
######################################################################
# Use the included network module to create a self-contained service
# (public ALB, private container instances and DB, with VPC, subnets,
# and everything needed for network connectivity). Simply provide
# the desired network ranges and the module will do the rest.
######################################################################
#
#vpc_cidr     = "10.20.30.0/24"
#public_cidr  = "10.20.30.0/25"
#private_cidr = "10.20.30.128/25"
#
######################################################################
# Or disable the network module and provide required network inputs.
# This is good if you have existing network infrastructure or want a
# private service with no Internet connectivity.
######################################################################
#
#enable_network       = false
#private_subnet_ids   = ["subnet-foo", "subnet-bar"]
#rds_source_region    = "us-east-1a"
#route_table_ids      = ["rtb-baz"]
#vpc_id               = "vpc-qux"
#
# EITHER provide public subnet IDs for Internet-facing service...
#public_subnet_ids     = ["subnet-12345678", "subnet-90123456"]
# OR set internal = true for private service...
#internal              = true

######################################################################
# Just plug in the missing <VALUES> and this mostly works... You can
# scale down to save cost. Scaling is best done by adding more tasks
# vs bigger tasks (scale out).
######################################################################

alb_certificate_arn = "<Generated in ACM>"
# This is an A record pointing to the ALB...
dns_name = "<Keycloak service FQDN>"
# ...in this hosted zone:
dns_zone_id = "<Route53 Zone ID>"
environment = "%%ENVIRONMENT%%"
region      = "%%REGION%%"

# READ THIS BEFORE CHANGING VALUES:
# https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_definition_parameters.html#task_size
container_cpu_units                = 1024
container_memory_limit             = 2048
container_memory_reserved          = 1024
jvm_heap_min                       = 512
jvm_heap_max                       = 1024
jvm_meta_min                       = 128
jvm_meta_max                       = 512
deployment_maximum_percent         = 100
deployment_minimum_healthy_percent = 50
desired_count                      = 2 # ECS tasks
log_retention_days                 = 5

# https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.DBInstanceClass.html
db_instance_type         = "db.r6g.large"
db_backup_retention_days = 5
db_cluster_size          = 2

# Aurora PostgreSQL Configuration
# Keycloak 26.4.4 official requirement: PostgreSQL 13.x minimum
#
# ⚠️ IMPORTANT: db_cluster_family MUST match the major version of db_engine_version
# Version mapping:
#   PostgreSQL 17.x → aurora-postgresql17
#   PostgreSQL 16.x → aurora-postgresql16
#   PostgreSQL 15.x → aurora-postgresql15
#   PostgreSQL 14.x → aurora-postgresql14
#   PostgreSQL 13.x → aurora-postgresql13
db_cluster_family        = "aurora-postgresql16"

# Engine version selection:
# Recommended: 16.8 (default) - Modern, stable, excellent performance
# Alternative options:
#   - 17.4: Latest with newest features (use with caution, may have unknown issues)
#   - 15.13/15.12: Conservative stable (LTS, widely tested)
#   - 14.17: Stable but 16.x preferred
#   - 13.20: Minimum requirement only, approaching EOL (not recommended)
#
# Check available versions for your region:
# aws rds describe-db-engine-versions --engine aurora-postgresql --region <region> \
#   --query 'DBEngineVersions[*].EngineVersion' --output text | tr '\t' '\n' | sort -V
#
# ⚠️ If you change this version, also update db_cluster_family above!
db_engine_version        = "16.8"  # Recommended: Best balance of modern features and stability
