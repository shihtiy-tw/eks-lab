# VPC Peering Setup for Cross-VPC Load Balancing (Terraform)

This directory contains Terraform configurations to set up two VPCs with peering connection for a cross-VPC load balancing scenario.

## Components

The Terraform configuration creates:

1. **VPC1 (EKS VPC)**:
   - CIDR: 10.0.0.0/16 (configurable)
   - 3 subnets across different AZs
   - Internet Gateway
   - Route table with routes to the internet and to VPC2

2. **VPC2 (NLB VPC)**:
   - CIDR: 10.1.0.0/16 (configurable)
   - 3 subnets across different AZs
   - Internet Gateway
   - Route table with routes to the internet and to VPC1

3. **VPC Peering Connection**:
   - Connects VPC1 and VPC2
   - Routes configured in both VPCs to allow cross-VPC communication

4. **Security Groups**:
   - EKS security group in VPC1
   - NLB security group in VPC2
   - Rules to allow traffic between the VPCs

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate permissions
- AWS provider >= 4.0.0

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the configuration:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

4. To customize the configuration, create a `terraform.tfvars` file based on the example:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your desired values
   ```

## Outputs

The Terraform configuration outputs the following values:

- `vpc1_id`: ID of VPC1 (EKS VPC)
- `vpc2_id`: ID of VPC2 (NLB VPC)
- `eks_subnet_ids`: IDs of EKS subnets
- `nlb_subnet_ids`: IDs of NLB subnets
- `eks_security_group_id`: ID of EKS security group
- `nlb_security_group_id`: ID of NLB security group
- `vpc_peering_id`: ID of VPC peering connection
- `cluster_name`: Name of the EKS cluster
- `region`: AWS region

These outputs can be used by other Terraform configurations or scripts to set up the EKS cluster and NLB.

## Cleanup

To destroy the resources:

```bash
terraform destroy
```

Note: Make sure to destroy any resources created in these VPCs before attempting to destroy the VPCs themselves.
---

# VPC Peering Setup for Cross-VPC Load Balancing

This directory contains scripts to set up two VPCs with peering connection for a cross-VPC load balancing scenario.

## Components

- **setup-vpcs.sh**: Creates two VPCs with subnets, internet gateways, and route tables
- **setup-vpc-peering.sh**: Establishes VPC peering connection and configures security groups

## Architecture

The setup creates:

1. **VPC1 (EKS VPC)**:
   - CIDR: 10.0.0.0/16
   - 3 subnets across different AZs
   - Internet Gateway
   - Route table with routes to the internet and to VPC2

2. **VPC2 (NLB VPC)**:
   - CIDR: 10.1.0.0/16
   - 3 subnets across different AZs
   - Internet Gateway
   - Route table with routes to the internet and to VPC1

3. **VPC Peering Connection**:
   - Connects VPC1 and VPC2
   - Routes configured in both VPCs to allow cross-VPC communication

4. **Security Groups**:
   - EKS security group in VPC1
   - NLB security group in VPC2
   - Rules to allow traffic between the VPCs

## Usage

1. Run the VPC setup script first:
   ```bash
   ./setup-vpcs.sh
   ```

2. Then run the VPC peering setup script:
   ```bash
   ./setup-vpc-peering.sh
   ```

The scripts will create a `vpc-config.env` file with all the resource IDs, which will be used by the EKS and NLB setup scripts.

## Cleanup

To clean up the resources:

1. Delete the VPC peering connection:
   ```bash
   PEERING_ID=$(grep PEERING_ID vpc-config.env | cut -d= -f2)
   aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PEERING_ID
   ```

2. Delete the security groups:
   ```bash
   EKS_SG_ID=$(grep EKS_SG_ID vpc-config.env | cut -d= -f2)
   NLB_SG_ID=$(grep NLB_SG_ID vpc-config.env | cut -d= -f2)
   aws ec2 delete-security-group --group-id $EKS_SG_ID
   aws ec2 delete-security-group --group-id $NLB_SG_ID
   ```

3. Delete the VPCs (this will also delete associated resources like subnets, route tables, etc.):
   ```bash
   VPC1_ID=$(grep VPC1_ID vpc-config.env | cut -d= -f2)
   VPC2_ID=$(grep VPC2_ID vpc-config.env | cut -d= -f2)
   aws ec2 delete-vpc --vpc-id $VPC1_ID
   aws ec2 delete-vpc --vpc-id $VPC2_ID
   ```

Note: Make sure to delete any resources created in these VPCs before attempting to delete the VPCs themselves.
