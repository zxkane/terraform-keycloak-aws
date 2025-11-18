# Makefile for MCP OAuth Realm Deployment
# Manages Terraform resources AND Client Registration Policies

.PHONY: help init plan apply deploy test destroy clean

help:
	@echo "MCP OAuth Realm Deployment"
	@echo "=========================="
	@echo ""
	@echo "Targets:"
	@echo "  init    - Initialize Terraform"
	@echo "  plan    - Run Terraform plan"
	@echo "  apply   - Apply Terraform configuration only"
	@echo "  deploy  - Full deployment (Terraform + DCR policies)"
	@echo "  test    - Test DCR endpoint"
	@echo "  destroy - Destroy all resources"
	@echo "  clean   - Clean Terraform state and cache"
	@echo ""
	@echo "Quick start:"
	@echo "  make deploy"
	@echo ""

init:
	@echo "Initializing Terraform..."
	@terraform init

plan: init
	@echo "Planning Terraform changes..."
	@terraform plan

apply: init
	@echo "Applying Terraform configuration..."
	@terraform apply -auto-approve

deploy: init
	@echo "=========================================="
	@echo "Full MCP OAuth Realm Deployment"
	@echo "=========================================="
	@./deploy.sh apply

test:
	@echo "Testing Dynamic Client Registration..."
	@./enable-dcr.sh

destroy:
	@echo "Destroying MCP OAuth Realm..."
	@terraform destroy -auto-approve

clean:
	@echo "Cleaning Terraform state and cache..."
	@rm -rf .terraform .terraform.lock.hcl terraform.tfstate* tfplan

.DEFAULT_GOAL := help
