# AWS EKS Module Outputs
# SRE Portfolio - Infrastructure as Code

output "cluster_id" {
  description = "Name/ID of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = aws_eks_cluster.main.status
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

# OIDC Provider outputs
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, "")
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider if enabled"
  value       = try(aws_iam_openid_connect_provider.cluster.arn, "")
}

# Node Groups outputs
output "node_groups" {
  description = "Map of attribute maps for all EKS managed node groups created"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn               = v.arn
      node_group_name   = v.node_group_name
      status            = v.status
      capacity_type     = v.capacity_type
      instance_types    = v.instance_types
      ami_type          = v.ami_type
      disk_size         = v.disk_size
      scaling_config    = v.scaling_config
      remote_access     = v.remote_access
      labels            = v.labels
      tags              = v.tags
    }
  }
}

output "node_group_arns" {
  description = "List of the EKS managed node group ARNs"
  value       = values(aws_eks_node_group.main)[*].arn
}

output "node_group_statuses" {
  description = "Status of the EKS managed node groups"
  value       = { for k, v in aws_eks_node_group.main : k => v.status }
}

output "node_security_group_arn" {
  description = "Amazon Resource Name (ARN) of the node shared security group"
  value       = try(aws_eks_cluster.main.vpc_config[0].cluster_security_group_id, "")
}

output "node_security_group_id" {
  description = "ID of the node shared security group"
  value       = try(aws_eks_cluster.main.vpc_config[0].cluster_security_group_id, "")
}

# Cluster Add-ons outputs
output "cluster_addons" {
  description = "Map of attribute maps for all EKS cluster addons enabled"
  value = {
    for k, v in aws_eks_addon.main : k => {
      arn               = v.arn
      addon_name        = v.addon_name
      addon_version     = v.addon_version
      status            = v.status
      resolve_conflicts = v.resolve_conflicts
    }
  }
}

# CloudWatch Log Group outputs
output "cloudwatch_log_group_name" {
  description = "Name of cloudwatch log group created"
  value       = aws_cloudwatch_log_group.cluster.name
}

output "cloudwatch_log_group_arn" {
  description = "Arn of cloudwatch log group created"
  value       = aws_cloudwatch_log_group.cluster.arn
}

# Service Account outputs
output "aws_load_balancer_controller_role_arn" {
  description = "ARN of the AWS Load Balancer Controller IAM role"
  value       = try(aws_iam_role.aws_load_balancer_controller[0].arn, "")
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of the EBS CSI Driver IAM role"
  value       = try(aws_iam_role.ebs_csi_driver[0].arn, "")
}

# Kubeconfig output
output "kubeconfig" {
  description = "Kubernetes config for the EKS cluster"
  value = {
    apiVersion = "v1"
    clusters = [{
      cluster = {
        certificate-authority-data = aws_eks_cluster.main.certificate_authority[0].data
        server                     = aws_eks_cluster.main.endpoint
      }
      name = aws_eks_cluster.main.arn
    }]
    contexts = [{
      context = {
        cluster = aws_eks_cluster.main.arn
        user    = aws_eks_cluster.main.arn
      }
      name = aws_eks_cluster.main.arn
    }]
    current-context = aws_eks_cluster.main.arn
    kind            = "Config"
    preferences     = {}
    users = [{
      name = aws_eks_cluster.main.arn
      user = {
        exec = {
          apiVersion = "client.authentication.k8s.io/v1beta1"
          command    = "aws"
          args       = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
        }
      }
    }]
  }
  sensitive = true
}

# Helm provider configuration output
output "helm_config" {
  description = "Helm provider configuration for the EKS cluster"
  value = {
    kubernetes = {
      host                   = aws_eks_cluster.main.endpoint
      cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
      token                  = data.aws_eks_cluster_auth.cluster.token
    }
  }
  sensitive = true
}

# Additional metadata outputs
output "cluster_tags" {
  description = "A map of tags assigned to the EKS cluster"
  value       = aws_eks_cluster.main.tags_all
}

output "cluster_vpc_config" {
  description = "VPC configuration of the EKS cluster"
  value = {
    subnet_ids              = aws_eks_cluster.main.vpc_config[0].subnet_ids
    security_group_ids      = aws_eks_cluster.main.vpc_config[0].security_group_ids
    vpc_id                  = aws_eks_cluster.main.vpc_config[0].vpc_id
    endpoint_private_access = aws_eks_cluster.main.vpc_config[0].endpoint_private_access
    endpoint_public_access  = aws_eks_cluster.main.vpc_config[0].endpoint_public_access
    public_access_cidrs     = aws_eks_cluster.main.vpc_config[0].public_access_cidrs
  }
}
