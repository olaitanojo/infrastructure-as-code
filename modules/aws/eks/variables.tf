# AWS EKS Module Variables
# SRE Portfolio - Infrastructure as Code

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  validation {
    condition     = length(var.cluster_name) <= 100
    error_message = "Cluster name must be 100 characters or less."
  }
}

variable "cluster_version" {
  description = "Kubernetes version to use for the EKS cluster"
  type        = string
  default     = "1.24"
  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+$", var.cluster_version))
    error_message = "Cluster version must be in format 'x.y'."
  }
}

variable "vpc_id" {
  description = "ID of the VPC where the cluster will be created"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the cluster"
  type        = list(string)
  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnets are required for EKS cluster."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for worker nodes"
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for worker nodes."
  }
}

variable "endpoint_private_access" {
  description = "Whether the Amazon EKS private API server endpoint is enabled"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Whether the Amazon EKS public API server endpoint is enabled"
  type        = bool
  default     = false
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the Amazon EKS public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_types" {
  description = "List of control plane logging to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  validation {
    condition = alltrue([
      for log_type in var.cluster_log_types : contains(["api", "audit", "authenticator", "controllerManager", "scheduler"], log_type)
    ])
    error_message = "Invalid log type. Valid types are: api, audit, authenticator, controllerManager, scheduler."
  }
}

variable "log_retention_in_days" {
  description = "Number of days to retain log events"
  type        = number
  default     = 7
  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653], var.log_retention_in_days)
    error_message = "Log retention must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653."
  }
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for encryption"
  type        = string
  default     = null
}

variable "node_groups" {
  description = "Map of EKS managed node group definitions"
  type = map(object({
    capacity_type                  = optional(string, "ON_DEMAND")
    instance_types                 = list(string)
    ami_type                      = optional(string, "AL2_x86_64")
    disk_size                     = optional(number, 100)
    desired_size                  = number
    max_size                      = number
    min_size                      = number
    max_unavailable_percentage    = optional(number, 25)
    key_name                      = optional(string, null)
    source_security_group_ids     = optional(list(string), [])
    labels                        = optional(map(string), {})
    tags                          = optional(map(string), {})
  }))
  default = {
    main = {
      instance_types = ["m5.large"]
      desired_size   = 3
      max_size       = 10
      min_size       = 1
    }
  }
  validation {
    condition = alltrue([
      for k, v in var.node_groups : v.min_size <= v.desired_size && v.desired_size <= v.max_size
    ])
    error_message = "For each node group, min_size <= desired_size <= max_size must be satisfied."
  }
}

variable "cluster_addons" {
  description = "Map of cluster addon configurations"
  type = map(object({
    version                   = optional(string, null)
    resolve_conflicts         = optional(string, "OVERWRITE")
    service_account_role_arn  = optional(string, null)
  }))
  default = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {
      resolve_conflicts = "OVERWRITE"
    }
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }
}

variable "enable_aws_load_balancer_controller" {
  description = "Whether to enable AWS Load Balancer Controller"
  type        = bool
  default     = true
}

variable "enable_ebs_csi_driver" {
  description = "Whether to enable EBS CSI Driver"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Map of tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Security-related variables
variable "enable_encryption_at_rest" {
  description = "Whether to enable encryption at rest for EKS secrets"
  type        = bool
  default     = true
}

variable "enable_pod_security_policy" {
  description = "Whether to enable Pod Security Policy"
  type        = bool
  default     = false
}

# Monitoring and observability
variable "enable_cluster_autoscaler" {
  description = "Whether to enable cluster autoscaler"
  type        = bool
  default     = true
}

variable "enable_metrics_server" {
  description = "Whether to enable metrics server"
  type        = bool
  default     = true
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# Network policies
variable "enable_network_policy" {
  description = "Whether to enable Kubernetes Network Policy"
  type        = bool
  default     = false
}

# IRSA (IAM Roles for Service Accounts)
variable "irsa_roles" {
  description = "Map of IRSA role configurations"
  type = map(object({
    namespace           = string
    service_account     = string
    policy_documents    = list(string)
    policy_arns         = optional(list(string), [])
  }))
  default = {}
}

# Fargate profiles
variable "fargate_profiles" {
  description = "Map of Fargate profile configurations"
  type = map(object({
    namespace = string
    labels    = optional(map(string), {})
    selectors = optional(list(object({
      namespace = string
      labels    = optional(map(string), {})
    })), [])
  }))
  default = {}
}
