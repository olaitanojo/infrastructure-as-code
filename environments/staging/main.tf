# Staging Environment Configuration
# SRE Portfolio - Infrastructure as Code

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  # Configure remote state backend
  backend "s3" {
    bucket         = "sre-portfolio-terraform-state"
    key            = "environments/staging/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "sre-portfolio-terraform-locks"
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment   = "staging"
      Project       = "sre-portfolio"
      ManagedBy     = "terraform"
      Owner         = "sre-team"
      CreatedDate   = formatdate("YYYY-MM-DD", timestamp())
    }
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# Local values
locals {
  name   = "sre-portfolio-staging"
  region = var.aws_region

  vpc_cidr = "10.1.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Environment = "staging"
    Project     = "sre-portfolio"
    Owner       = "sre-team"
  }
}

# Random suffix for unique resource names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# VPC Module
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
  public_subnets  = ["10.1.4.0/24", "10.1.5.0/24", "10.1.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = false # Multi-AZ for staging
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Enable flow logs for security monitoring
  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  # Kubernetes subnet tags
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${local.name}-eks" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${local.name}-eks" = "owned"
  }

  tags = local.common_tags
}

# KMS Key for encryption
resource "aws_kms_key" "eks" {
  description             = "${local.name} EKS Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${local.name}-eks-encryption-key"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${local.name}-eks"
  target_key_id = aws_kms_key.eks.key_id
}

# EKS Cluster
module "eks" {
  source = "../../modules/aws/eks"

  cluster_name    = "${local.name}-eks"
  cluster_version = "1.28"

  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr_block
  subnet_ids         = module.vpc.public_subnets
  private_subnet_ids = module.vpc.private_subnets

  # Security configuration
  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs     = ["10.1.0.0/16"] # More restrictive for staging
  kms_key_arn            = aws_kms_key.eks.arn

  # Logging
  cluster_log_types        = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_in_days   = 14 # Longer retention for staging

  # Node Groups
  node_groups = {
    general = {
      instance_types = ["t3.large"] # Larger instances for staging
      capacity_type  = "ON_DEMAND"  # More reliable for staging
      
      desired_size = 2
      max_size     = 6
      min_size     = 2
      
      disk_size = 100

      labels = {
        role = "general"
        env  = "staging"
      }
    }

    monitoring = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      
      desired_size = 2
      max_size     = 3
      min_size     = 1
      
      disk_size = 50

      labels = {
        role = "monitoring"
        env  = "staging"
      }
    }
  }

  # Addons
  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  # Enable additional components
  enable_aws_load_balancer_controller = true
  enable_ebs_csi_driver              = true

  tags = local.common_tags
}
