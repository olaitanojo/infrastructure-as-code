# Development Environment Outputs
# SRE Portfolio - Infrastructure as Code

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = module.vpc.natgw_ids
}

# EKS Cluster Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = module.eks.cluster_oidc_issuer_url
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = module.eks.oidc_provider_arn
}

# Node Group Outputs
output "node_groups" {
  description = "EKS node groups information"
  value       = module.eks.node_groups
}

output "node_group_arns" {
  description = "Amazon Resource Names (ARN) of the EKS Node Groups"
  value       = module.eks.node_group_arns
}

# Service Account Role Outputs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = module.eks.aws_load_balancer_controller_role_arn
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role"
  value       = module.eks.ebs_csi_driver_role_arn
}

# Database Outputs
output "database_endpoint" {
  description = "Endpoint of the RDS database"
  value       = aws_db_instance.dev.endpoint
}

output "database_port" {
  description = "Port of the RDS database"
  value       = aws_db_instance.dev.port
}

output "database_name" {
  description = "Name of the database"
  value       = aws_db_instance.dev.db_name
}

output "database_username" {
  description = "Username for the database"
  value       = aws_db_instance.dev.username
  sensitive   = true
}

output "database_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

# Storage Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket for application storage"
  value       = aws_s3_bucket.app_storage.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for application storage"
  value       = aws_s3_bucket.app_storage.arn
}

# Container Registry Outputs
output "ecr_repository_urls" {
  description = "Map of ECR repository URLs"
  value = {
    for name, repo in aws_ecr_repository.apps : name => repo.repository_url
  }
}

output "ecr_repository_arns" {
  description = "Map of ECR repository ARNs"
  value = {
    for name, repo in aws_ecr_repository.apps : name => repo.arn
  }
}

# Security Outputs
output "kms_key_id" {
  description = "KMS Key ID used for encryption"
  value       = aws_kms_key.eks.key_id
}

output "kms_key_arn" {
  description = "KMS Key ARN used for encryption"
  value       = aws_kms_key.eks.arn
}

# Kubernetes Configuration Output (for local development)
output "kubeconfig_command" {
  description = "Command to update kubeconfig for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_id}"
}

# Monitoring and Logging Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS"
  value       = module.eks.cloudwatch_log_group_name
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS"
  value       = module.eks.cloudwatch_log_group_arn
}

# Connection Information
output "connection_info" {
  description = "Connection information for various services"
  value = {
    cluster = {
      name     = module.eks.cluster_id
      endpoint = module.eks.cluster_endpoint
      region   = var.aws_region
    }
    database = {
      endpoint = aws_db_instance.dev.endpoint
      port     = aws_db_instance.dev.port
      database = aws_db_instance.dev.db_name
    }
    storage = {
      s3_bucket = aws_s3_bucket.app_storage.bucket
      kms_key   = aws_kms_key.eks.key_id
    }
  }
  sensitive = true
}

# Environment Summary
output "environment_summary" {
  description = "Summary of the deployed development environment"
  value = {
    environment       = "development"
    cluster_name      = module.eks.cluster_id
    cluster_version   = module.eks.cluster_version
    region           = var.aws_region
    vpc_cidr         = module.vpc.vpc_cidr_block
    node_groups      = length(module.eks.node_groups)
    availability_zones = length(local.azs)
    cost_optimized   = var.cost_optimization.use_spot_instances
    monitoring       = var.enable_monitoring
    backup_enabled   = var.enable_backup
  }
}

# Cost Optimization Information
output "cost_optimization_features" {
  description = "List of cost optimization features enabled"
  value = [
    var.cost_optimization.use_spot_instances ? "Spot instances enabled" : "On-demand instances only",
    var.cost_optimization.single_nat_gateway ? "Single NAT gateway" : "Multiple NAT gateways",
    var.cost_optimization.smaller_db_instance ? "Small DB instance (${var.db_instance_class})" : "Standard DB instance",
    var.cost_optimization.reduced_log_retention ? "Reduced log retention (${var.monitoring_configuration.cloudwatch_log_retention} days)" : "Standard log retention"
  ]
}

# Security Features
output "security_features" {
  description = "List of security features enabled"
  value = [
    "Encryption at rest with KMS",
    "Private subnets for worker nodes",
    "VPC Flow Logs enabled",
    "Database in private subnet",
    "S3 bucket with public access blocked",
    "IAM roles with least privilege",
    "Container image vulnerability scanning"
  ]
}

# Next Steps Information
output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = [
    "Update kubeconfig: aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_id}",
    "Install kubectl: https://kubernetes.io/docs/tasks/tools/",
    "Deploy monitoring stack to 'monitoring' node group",
    "Set up CI/CD pipeline to deploy applications",
    "Configure application secrets in AWS Secrets Manager",
    "Deploy ingress controller for external access"
  ]
}
