variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "cluster_name" {
  type    = string
  default = "rearc-quest-eks"
}

variable "image_uri" {
  type        = string
  description = "ECR image URI, e.g. <acct>.dkr.ecr.<region>.amazonaws.com/rearc-quest:latest"
}

variable "secret_word" {
  type        = string
  description = "Phase 2: paste value obtained from GET /"
  default     = ""
}

variable "eks_admin_principal_arn" {
  type        = string
  description = "IAM user/role ARN that should have EKS cluster-admin access"
}

variable "cert_pem_path" {
  type    = string
  default = "../certs/cert.pem"
}

variable "key_pem_path" {
  type    = string
  default = "../certs/key.pem"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "desired_size" {
  type    = number
  default = 2
}
variable "min_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 3
}

# variable "name_prefix" {
#   type        = string
#   description = "Name prefix for resources"
#   default     = "questex"
# }