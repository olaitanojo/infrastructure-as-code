# Infrastructure as Code - Makefile
# SRE Portfolio Project

.PHONY: help init plan apply destroy test validate format lint docs security
.DEFAULT_GOAL := help

# Environment variables
TF_VERSION := 1.6.0
TERRAGRUNT_VERSION := 0.53.0
ENVIRONMENT ?= dev

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Infrastructure as Code - Available Commands$(NC)"
	@echo "$(YELLOW)===========================================$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# ==============================================================================
# Setup and Installation
# ==============================================================================

setup: ## Install required tools and dependencies
	@echo "$(BLUE)Installing required tools...$(NC)"
	@./scripts/setup/install-tools.sh
	@./scripts/setup/setup-env.sh

check-tools: ## Verify all required tools are installed
	@echo "$(BLUE)Checking required tools...$(NC)"
	@./scripts/validation/check-tools.sh

# ==============================================================================
# Environment Management
# ==============================================================================

init-dev: ## Initialize development environment
	@echo "$(BLUE)Initializing development environment...$(NC)"
	@cd environments/dev && terraform init
	@cd environments/dev && terraform workspace select dev || terraform workspace new dev

init-staging: ## Initialize staging environment
	@echo "$(BLUE)Initializing staging environment...$(NC)"
	@cd environments/staging && terraform init
	@cd environments/staging && terraform workspace select staging || terraform workspace new staging

init-production: ## Initialize production environment
	@echo "$(BLUE)Initializing production environment...$(NC)"
	@cd environments/production && terraform init
	@cd environments/production && terraform workspace select production || terraform workspace new production

plan-dev: ## Plan changes for development environment
	@echo "$(BLUE)Planning development environment...$(NC)"
	@cd environments/dev && terraform plan -out=tfplan

plan-staging: ## Plan changes for staging environment
	@echo "$(BLUE)Planning staging environment...$(NC)"
	@cd environments/staging && terraform plan -out=tfplan

plan-production: ## Plan changes for production environment
	@echo "$(BLUE)Planning production environment...$(NC)"
	@cd environments/production && terraform plan -out=tfplan

apply-dev: ## Apply changes to development environment
	@echo "$(BLUE)Applying development environment...$(NC)"
	@cd environments/dev && terraform apply tfplan

apply-staging: ## Apply changes to staging environment
	@echo "$(YELLOW)Applying staging environment...$(NC)"
	@cd environments/staging && terraform apply tfplan

apply-production: ## Apply changes to production environment (requires approval)
	@echo "$(RED)Applying production environment...$(NC)"
	@echo "$(RED)⚠️  PRODUCTION DEPLOYMENT - Requires manual approval$(NC)"
	@read -p "Continue with production deployment? (y/N): " confirm && [ "$$confirm" = "y" ]
	@cd environments/production && terraform apply tfplan

destroy-dev: ## Destroy development environment
	@echo "$(RED)Destroying development environment...$(NC)"
	@cd environments/dev && terraform destroy -auto-approve

destroy-staging: ## Destroy staging environment
	@echo "$(RED)Destroying staging environment...$(NC)"
	@cd environments/staging && terraform destroy -auto-approve

destroy-production: ## Destroy production environment (requires approval)
	@echo "$(RED)⚠️  DESTROYING PRODUCTION ENVIRONMENT$(NC)"
	@read -p "Are you sure you want to destroy production? Type 'destroy-production': " confirm && [ "$$confirm" = "destroy-production" ]
	@cd environments/production && terraform destroy

# ==============================================================================
# Multi-Environment Operations
# ==============================================================================

promote-staging: init-staging plan-staging ## Promote changes to staging
	@echo "$(YELLOW)Promoting to staging environment...$(NC)"
	@$(MAKE) apply-staging

promote-production: init-production plan-production ## Promote changes to production
	@echo "$(RED)Promoting to production environment...$(NC)"
	@$(MAKE) apply-production

# ==============================================================================
# Testing
# ==============================================================================

test-unit: ## Run unit tests for Terraform modules
	@echo "$(BLUE)Running unit tests...$(NC)"
	@cd tests/unit && go test -v ./...

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@cd tests/integration && go test -v -timeout=30m ./...

test-dev: ## Test development environment
	@echo "$(BLUE)Testing development environment...$(NC)"
	@./scripts/validation/test-environment.sh dev

test-staging: ## Test staging environment
	@echo "$(BLUE)Testing staging environment...$(NC)"
	@./scripts/validation/test-environment.sh staging

test-production: ## Test production environment
	@echo "$(BLUE)Testing production environment...$(NC)"
	@./scripts/validation/test-environment.sh production

test-all: test-unit test-integration ## Run all tests

# ==============================================================================
# Validation and Quality
# ==============================================================================

validate: ## Validate Terraform configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@find . -name "*.tf" -exec dirname {} \; | sort -u | xargs -I {} sh -c 'cd {} && terraform validate'

format: ## Format Terraform code
	@echo "$(BLUE)Formatting Terraform code...$(NC)"
	@terraform fmt -recursive .

lint: ## Lint Terraform configuration
	@echo "$(BLUE)Linting Terraform configuration...$(NC)"
	@tflint --recursive

pre-commit: validate format lint ## Run pre-commit checks

# ==============================================================================
# Security and Compliance
# ==============================================================================

security-scan: ## Run security scans on infrastructure code
	@echo "$(BLUE)Running security scans...$(NC)"
	@checkov -d . --framework terraform
	@tfsec .
	@terrascan scan -t terraform -d .

policy-check: ## Check policies with OPA
	@echo "$(BLUE)Checking policies...$(NC)"
	@opa test policies/

compliance-check: ## Check compliance requirements
	@echo "$(BLUE)Checking compliance...$(NC)"
	@./scripts/validation/compliance-check.sh

# ==============================================================================
# Monitoring and Drift Detection
# ==============================================================================

drift-detection: ## Check for configuration drift
	@echo "$(BLUE)Checking for configuration drift...$(NC)"
	@./scripts/validation/drift-detection.sh

drift-report: ## Generate drift detection report
	@echo "$(BLUE)Generating drift report...$(NC)"
	@./scripts/utilities/generate-drift-report.sh

cost-analysis: ## Generate cost analysis report
	@echo "$(BLUE)Generating cost analysis...$(NC)"
	@./scripts/utilities/cost-analysis.sh

optimize-resources: ## Generate resource optimization recommendations
	@echo "$(BLUE)Generating optimization recommendations...$(NC)"
	@./scripts/utilities/optimize-resources.sh

# ==============================================================================
# Documentation
# ==============================================================================

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@terraform-docs markdown table --output-file README.md --output-mode inject ./modules/aws
	@terraform-docs markdown table --output-file README.md --output-mode inject ./modules/gcp
	@terraform-docs markdown table --output-file README.md --output-mode inject ./modules/azure

diagram: ## Generate architecture diagrams
	@echo "$(BLUE)Generating architecture diagrams...$(NC)"
	@./scripts/utilities/generate-diagrams.sh

# ==============================================================================
# State Management
# ==============================================================================

state-list: ## List resources in Terraform state
	@echo "$(BLUE)Listing Terraform state...$(NC)"
	@cd environments/$(ENVIRONMENT) && terraform state list

state-show: ## Show specific resource from state
	@echo "$(BLUE)Showing resource from state...$(NC)"
	@cd environments/$(ENVIRONMENT) && terraform state show $(RESOURCE)

state-backup: ## Backup Terraform state
	@echo "$(BLUE)Backing up Terraform state...$(NC)"
	@./scripts/utilities/backup-state.sh $(ENVIRONMENT)

state-restore: ## Restore Terraform state from backup
	@echo "$(BLUE)Restoring Terraform state...$(NC)"
	@./scripts/utilities/restore-state.sh $(ENVIRONMENT) $(BACKUP_FILE)

# ==============================================================================
# Utilities
# ==============================================================================

clean: ## Clean temporary files and caches
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -delete
	@find . -name ".terraform.lock.hcl" -delete

outputs: ## Show outputs for environment
	@echo "$(BLUE)Showing outputs for $(ENVIRONMENT)...$(NC)"
	@cd environments/$(ENVIRONMENT) && terraform output

refresh: ## Refresh Terraform state
	@echo "$(BLUE)Refreshing Terraform state for $(ENVIRONMENT)...$(NC)"
	@cd environments/$(ENVIRONMENT) && terraform refresh

unlock: ## Unlock Terraform state
	@echo "$(BLUE)Unlocking Terraform state for $(ENVIRONMENT)...$(NC)"
	@cd environments/$(ENVIRONMENT) && terraform force-unlock $(LOCK_ID)

# ==============================================================================
# CI/CD Integration
# ==============================================================================

ci-validate: validate lint security-scan ## CI validation pipeline
	@echo "$(GREEN)CI validation completed successfully$(NC)"

ci-plan: ## CI plan pipeline
	@echo "$(BLUE)Running CI plan pipeline...$(NC)"
	@$(MAKE) plan-$(ENVIRONMENT)

ci-apply: ## CI apply pipeline
	@echo "$(BLUE)Running CI apply pipeline...$(NC)"
	@$(MAKE) apply-$(ENVIRONMENT)

ci-test: test-all ## CI test pipeline
	@echo "$(GREEN)CI test pipeline completed successfully$(NC)"

# ==============================================================================
# Development Helpers
# ==============================================================================

dev-destroy-recreate: destroy-dev init-dev plan-dev apply-dev ## Destroy and recreate dev environment
	@echo "$(GREEN)Development environment recreated$(NC)"

staging-promote: plan-staging apply-staging test-staging ## Full staging promotion
	@echo "$(GREEN)Staging promotion completed$(NC)"

production-deploy: plan-production apply-production test-production ## Full production deployment
	@echo "$(GREEN)Production deployment completed$(NC)"}
