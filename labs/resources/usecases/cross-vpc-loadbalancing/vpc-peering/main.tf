provider "aws" {
  region = var.region
}

# VPC 1 - EKS VPC
resource "aws_vpc" "eks_vpc" {
  cidr_block           = var.vpc1_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "eks-vpc"
  }
}

# VPC 2 - NLB VPC
resource "aws_vpc" "nlb_vpc" {
  cidr_block           = var.vpc2_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "nlb-vpc"
  }
}

# Internet Gateway for VPC 1
resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-igw"
  }
}

# Internet Gateway for VPC 2
resource "aws_internet_gateway" "nlb_igw" {
  vpc_id = aws_vpc.nlb_vpc.id

  tags = {
    Name = "nlb-igw"
  }
}

# Subnets for VPC 1 (EKS)
resource "aws_subnet" "eks_subnet" {
  count = 3

  vpc_id                  = aws_vpc.eks_vpc.id
  cidr_block              = cidrsubnet(var.vpc1_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                          = "eks-subnet-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }
}

# Subnets for VPC 2 (NLB)
resource "aws_subnet" "nlb_subnet" {
  count = 3

  vpc_id                  = aws_vpc.nlb_vpc.id
  cidr_block              = cidrsubnet(var.vpc2_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "nlb-subnet-${count.index + 1}"
  }
}

# Route Table for VPC 1
resource "aws_route_table" "eks_rtb" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-rtb"
  }
}

# Route Table for VPC 2
resource "aws_route_table" "nlb_rtb" {
  vpc_id = aws_vpc.nlb_vpc.id

  tags = {
    Name = "nlb-rtb"
  }
}

# Internet Route for VPC 1
resource "aws_route" "eks_internet_route" {
  route_table_id         = aws_route_table.eks_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.eks_igw.id
}

# Internet Route for VPC 2
resource "aws_route" "nlb_internet_route" {
  route_table_id         = aws_route_table.nlb_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.nlb_igw.id
}

# Route Table Association for VPC 1
resource "aws_route_table_association" "eks_rta" {
  count = 3

  subnet_id      = aws_subnet.eks_subnet[count.index].id
  route_table_id = aws_route_table.eks_rtb.id
}

# Route Table Association for VPC 2
resource "aws_route_table_association" "nlb_rta" {
  count = 3

  subnet_id      = aws_subnet.nlb_subnet[count.index].id
  route_table_id = aws_route_table.nlb_rtb.id
}

# VPC Peering Connection
resource "aws_vpc_peering_connection" "vpc_peering" {
  vpc_id        = aws_vpc.eks_vpc.id
  peer_vpc_id   = aws_vpc.nlb_vpc.id
  auto_accept   = true

  tags = {
    Name = "eks-nlb-peering"
  }
}

# Route from VPC 1 to VPC 2
resource "aws_route" "eks_to_nlb" {
  route_table_id            = aws_route_table.eks_rtb.id
  destination_cidr_block    = var.vpc2_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Route from VPC 2 to VPC 1
resource "aws_route" "nlb_to_eks" {
  route_table_id            = aws_route_table.nlb_rtb.id
  destination_cidr_block    = var.vpc1_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.vpc_peering.id
}

# Security Group for EKS nodes
resource "aws_security_group" "eks_sg" {
  name        = "eks-nodes-sg"
  description = "Security group for EKS nodes"
  vpc_id      = aws_vpc.eks_vpc.id

  tags = {
    Name = "eks-nodes-sg"
  }
}

# Security Group for NLB
resource "aws_security_group" "nlb_sg" {
  name        = "nlb-sg"
  description = "Security group for NLB"
  vpc_id      = aws_vpc.nlb_vpc.id

  tags = {
    Name = "nlb-sg"
  }
}

# Security Group Rule - Allow inbound traffic from NLB SG to EKS SG
resource "aws_security_group_rule" "nlb_to_eks" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_sg.id
  source_security_group_id = aws_security_group.nlb_sg.id
}

# Security Group Rule - Allow outbound traffic from NLB SG to EKS VPC
resource "aws_security_group_rule" "nlb_to_eks_outbound" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.nlb_sg.id
  cidr_blocks       = [var.vpc1_cidr]
}

# Security Group Rule - Allow inbound traffic from anywhere to NLB SG
resource "aws_security_group_rule" "internet_to_nlb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.nlb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
}

# Data source for availability zones
data "aws_availability_zones" "available" {
  state = "available"
}
