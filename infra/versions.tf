terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
  backend "s3" {
    bucket  = "quest-demo-tf-state"
    key     = "quest-demo-exercise/terraform.tfstate"
    region  = "us-east-2"
    encrypt = true
  }
}