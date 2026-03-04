# provider "aws" {
#   region = var.aws_region
# }

locals {
#   name = var.name_prefix
  tags = {
    Project = "quest-demo"
    Lab     = "true"
  }
}

data "aws_availability_zones" "az" {}


# ---------------------------
# Networking (VPC)
# ---------------------------
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs            = slice(data.aws_availability_zones.az.names, 0, 2)
  public_subnets = ["10.0.0.0/24", "10.0.1.0/24"]

  enable_nat_gateway = false
  single_nat_gateway = false

  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }
}

# ---------------------------
# EKS Cluster 
# ---------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_irsa = true

  eks_managed_node_groups = {
    main = {
      instance_types = var.node_instance_types
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
    }
  }
}

# ---------------
# Kubernetes + Helm providers (talk to the created cluster)
# ---------------
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name

  # Makes intent explicit; avoids edge timing issues.
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}


# ---------------
# ACM: import self-signed cert for HTTPS on ALB
# ---------------
resource "aws_acm_certificate" "selfsigned" {
  private_key      = file(var.key_pem_path)
  certificate_body = file(var.cert_pem_path)
}

# -----------------
# IRSA for AWS Load Balancer Controller
# Uses terraform-aws-modules/iam submodule which can attach the LBC policy. :contentReference[oaicite:1]{index=1}
# ------------------
module "lbc_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-aws-lbc"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# --------------
# ServiceAccount for controller (annotated with IRSA role)
# --------------
resource "kubernetes_service_account_v1" "aws_lbc" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"

    annotations = {
      "eks.amazonaws.com/role-arn" = module.lbc_irsa.iam_role_arn
    }
  }

  depends_on = [module.eks]
}

# ------------------
# Install AWS Load Balancer Controller Helm chart
# ------------------
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      region      = var.aws_region
      vpcId       = module.vpc.vpc_id

      serviceAccount = {
        create = false
        name   = kubernetes_service_account_v1.aws_lbc.metadata[0].name
      }
    })
  ]

  depends_on = [kubernetes_service_account_v1.aws_lbc]
}


# # ---------------------------
# # Container Registry (ECR)
# # ---------------------------
# resource "aws_ecr_repository" "questapp" {
#   name = "rearc-quest"
#   image_scanning_configuration {
#     scan_on_push = true
#   }
#   tags = local.tags
# }