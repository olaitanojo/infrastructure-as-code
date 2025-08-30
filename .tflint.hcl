# TFLint Configuration
# This file configures TFLint rules for the infrastructure-as-code project

config {
  # Enable all rules by default
  module = true
  force = false
  disabled_by_default = false
}

# AWS plugin configuration
plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Enable specific rules
rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}

# Disable some rules that might be too strict for our setup
rule "terraform_typed_variables" {
  enabled = false
}

rule "aws_resource_missing_tags" {
  enabled = false  # We handle tags at the provider level
}

rule "aws_db_instance_backup_retention_period_specified" {
  enabled = false  # We specify this explicitly based on environment
}
