variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "vpc1_cidr" {
  description = "CIDR block for VPC1 (EKS VPC)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc2_cidr" {
  description = "CIDR block for VPC2 (NLB VPC)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "cross-vpc-demo"
}
