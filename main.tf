# main.tf
# Tiered Identity Proof of Concept
# Extends: Building Secure Cloud Architecture for AWS
# Author: Isaac Pyram

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project   = "Dual identity problem"
      ManagedBy = "Terraform"
    }
  }
}
