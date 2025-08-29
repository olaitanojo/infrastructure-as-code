# Development Environment Variables
# SRE Portfolio - Infrastructure as Code

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-west-2"
  validation {
    condition = contains([
      "us-east-1", "us-east-2", "us-west-1", "us-west-2",
      "eu-west-1", "eu-west-2", "eu-central-1",
      "ap-southeast-1", "ap-southeast-2", "ap-northeast-1"
    ], var.aws_region)
    error_message = "AWS region must be a valid region."
  }
}

variable "application_names" {
  description = "List of application names for ECR repositories"
  type        = list(string)
  default = [
    "prometheus-monitoring",
    "incident-response",
    "log-aggregation", 
    "capacity-planning",
    "ci-cd-pipeline"
  ]
  validation {
    condition     = length(var.application_names) > 0
    error_message = "At least one application name must be provided."
  }
}

variable "enable_monitoring" {
  description = "Enable enhanced monitoring and logging"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable automated backup for RDS"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 35
    error_message = "Backup retention days must be between 1 and 35."
  }
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition = can(regex("^db\\.", var.db_instance_class))
    error_message = "DB instance class must start with 'db.'."
  }
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for critical resources"
  type        = bool
  default     = false # Disabled for dev environment
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access the cluster"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Open for dev, restrict for production
  validation {
    condition = alltrue([
      for cidr in var.allowed_cidr_blocks : can(cidrhost(cidr, 0))
    ])
    error_message = "All CIDR blocks must be valid."
  }
}

variable "node_group_scaling" {
  description = "Node group scaling configuration"
  type = object({
    min_size     = number
    max_size     = number
    desired_size = number
  })
  default = {
    min_size     = 1
    max_size     = 5
    desired_size = 2
  }
  validation {
    condition = (
      var.node_group_scaling.min_size <= var.node_group_scaling.desired_size &&
      var.node_group_scaling.desired_size <= var.node_group_scaling.max_size &&
      var.node_group_scaling.min_size >= 1
    )
    error_message = "Node group scaling must satisfy: min_size <= desired_size <= max_size and min_size >= 1."
  }
}

variable "cost_optimization" {
  description = "Enable cost optimization features for development"
  type = object({
    use_spot_instances    = bool
    single_nat_gateway   = bool
    smaller_db_instance  = bool
    reduced_log_retention = bool
  })
  default = {
    use_spot_instances    = true
    single_nat_gateway   = true
    smaller_db_instance  = true
    reduced_log_retention = true
  }
}

variable "security_groups" {
  description = "Additional security group configurations"
  type = object({
    enable_ssh_access = bool
    ssh_cidr_blocks  = list(string)
    additional_ports = list(number)
  })
  default = {
    enable_ssh_access = false
    ssh_cidr_blocks  = []
    additional_ports = []
  }
}

variable "storage_configuration" {
  description = "Storage configuration for various components"
  type = object({
    rds_storage_size    = number
    rds_max_storage    = number
    ebs_volume_size    = number
    s3_lifecycle_days  = number
  })
  default = {
    rds_storage_size   = 20
    rds_max_storage   = 100
    ebs_volume_size   = 50
    s3_lifecycle_days = 30
  }
  validation {
    condition = (
      var.storage_configuration.rds_storage_size <= var.storage_configuration.rds_max_storage &&
      var.storage_configuration.ebs_volume_size >= 20
    )
    error_message = "Storage configuration must be valid: RDS max >= initial size, EBS >= 20GB."
  }
}

variable "monitoring_configuration" {
  description = "Monitoring and observability configuration"
  type = object({
    enable_container_insights = bool
    enable_performance_insights = bool
    cloudwatch_log_retention = number
    enable_xray_tracing = bool
  })
  default = {
    enable_container_insights   = true
    enable_performance_insights = false # Cost optimization for dev
    cloudwatch_log_retention   = 7      # Short retention for dev
    enable_xray_tracing        = false  # Disabled for cost optimization
  }
}

variable "network_configuration" {
  description = "Network configuration settings"
  type = object({
    vpc_cidr            = string
    enable_flow_logs    = bool
    enable_nat_gateway  = bool
    availability_zones  = number
  })
  default = {
    vpc_cidr           = "10.0.0.0/16"
    enable_flow_logs   = true
    enable_nat_gateway = true
    availability_zones = 3
  }
  validation {
    condition = (
      can(cidrhost(var.network_configuration.vpc_cidr, 0)) &&
      var.network_configuration.availability_zones >= 2 &&
      var.network_configuration.availability_zones <= 6
    )
    error_message = "Network configuration must have valid VPC CIDR and 2-6 availability zones."
  }
}

variable "kubernetes_configuration" {
  description = "Kubernetes-specific configuration"
  type = object({
    version = string
    addons = object({
      enable_aws_load_balancer_controller = bool
      enable_cluster_autoscaler          = bool
      enable_metrics_server              = bool
      enable_aws_ebs_csi_driver          = bool
    })
  })
  default = {
    version = "1.28"
    addons = {
      enable_aws_load_balancer_controller = true
      enable_cluster_autoscaler          = true
      enable_metrics_server              = true
      enable_aws_ebs_csi_driver          = true
    }
  }
  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.kubernetes_configuration.version))
    error_message = "Kubernetes version must be in format '1.x'."
  }
}

variable "environment_specific_tags" {
  description = "Environment-specific tags to apply to all resources"
  type        = map(string)
  default = {
    Environment         = "development"
    CostCenter         = "engineering"
    MaintenanceWindow  = "weekends"
    BackupRequired     = "true"
    MonitoringLevel    = "basic"
  }
}
