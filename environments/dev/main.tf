# Development Environment Configuration
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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Configure remote state backend
  backend "s3" {
    bucket         = "sre-portfolio-terraform-state"
    key            = "environments/dev/terraform.tfstate"
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
      Environment   = "development"
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
  name   = "sre-portfolio-dev"
  region = var.aws_region

  vpc_cidr = "10.0.0.0/16"
  azs      = slice(data.aws_availability_zones.available.names, 0, 3)

  common_tags = {
    Environment = "development"
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
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true # Cost optimization for dev environment
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
  public_access_cidrs     = ["0.0.0.0/0"] # Restrict this in production
  kms_key_arn            = aws_kms_key.eks.arn

  # Logging
  cluster_log_types        = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  log_retention_in_days   = 7 # Cost optimization for dev

  # Node Groups
  node_groups = {
    general = {
      instance_types = ["t3.medium"] # Cost-optimized for dev
      capacity_type  = "SPOT"        # Further cost optimization
      
      desired_size = 2
      max_size     = 4
      min_size     = 1
      
      disk_size = 50 # Smaller disk for dev

      labels = {
        role = "general"
        env  = "dev"
      }
    }

    monitoring = {
      instance_types = ["t3.small"]
      capacity_type  = "ON_DEMAND" # Monitoring needs stability
      
      desired_size = 1
      max_size     = 2
      min_size     = 1
      
      disk_size = 30

      labels = {
        role = "monitoring"
        env  = "dev"
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

# RDS Database for development
resource "aws_db_subnet_group" "dev" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.common_tags, {
    Name = "${local.name}-db-subnet-group"
  })
}

resource "aws_security_group" "rds" {
  name_prefix = "${local.name}-rds-"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for RDS database"

  ingress {
    description = "PostgreSQL from EKS nodes"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-rds-sg"
  })
}

resource "random_password" "db_password" {
  length  = 16
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.name}-db-password-${random_string.suffix.result}"
  description = "Database password for ${local.name}"

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

resource "aws_db_instance" "dev" {
  identifier = "${local.name}-postgres"

  # Engine configuration
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro" # Cost-optimized for dev

  # Storage configuration
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id           = aws_kms_key.eks.arn

  # Database configuration
  db_name  = "sreportfolio"
  username = "postgres"
  password = random_password.db_password.result

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.dev.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Backup configuration
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  # Monitoring
  monitoring_interval = 60
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Development optimizations
  skip_final_snapshot = true
  deletion_protection = false

  tags = merge(local.common_tags, {
    Name = "${local.name}-postgres"
  })
}

# S3 Bucket for application storage
resource "aws_s3_bucket" "app_storage" {
  bucket = "${local.name}-app-storage-${random_string.suffix.result}"

  tags = merge(local.common_tags, {
    Name = "${local.name}-app-storage"
  })
}

resource "aws_s3_bucket_versioning" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.eks.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "app_storage" {
  bucket = aws_s3_bucket.app_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECR Repository for container images
resource "aws_ecr_repository" "apps" {
  for_each = toset(var.application_names)
  
  name                 = "${local.name}/${each.key}"
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key        = aws_kms_key.eks.arn
  }

  tags = merge(local.common_tags, {
    Name = "${local.name}-${each.key}"
  })
}

resource "aws_ecr_lifecycle_policy" "apps" {
  for_each = aws_ecr_repository.apps
  
  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
