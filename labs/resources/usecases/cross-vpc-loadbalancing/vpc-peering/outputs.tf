output "vpc1_id" {
  description = "ID of VPC1 (EKS VPC)"
  value       = aws_vpc.eks_vpc.id
}

output "vpc2_id" {
  description = "ID of VPC2 (NLB VPC)"
  value       = aws_vpc.nlb_vpc.id
}

output "eks_subnet_ids" {
  description = "IDs of EKS subnets"
  value       = aws_subnet.eks_subnet[*].id
}

output "nlb_subnet_ids" {
  description = "IDs of NLB subnets"
  value       = aws_subnet.nlb_subnet[*].id
}

output "eks_security_group_id" {
  description = "ID of EKS security group"
  value       = aws_security_group.eks_sg.id
}

output "nlb_security_group_id" {
  description = "ID of NLB security group"
  value       = aws_security_group.nlb_sg.id
}

output "vpc_peering_id" {
  description = "ID of VPC peering connection"
  value       = aws_vpc_peering_connection.vpc_peering.id
}

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = var.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.region
}
