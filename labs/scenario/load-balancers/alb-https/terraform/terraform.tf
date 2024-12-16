terraform {
  required_version = "~> 1.6"
  required_providers {
    # https://registry.terraform.io/providers/hashicorp/aws/latest
    aws = {
      source  = "hashicorp/aws"
      version = "5.70.0"
    }
  }
}
