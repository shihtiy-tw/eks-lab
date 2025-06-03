# EKS and NLB Setup for Cross-VPC Load Balancing (Terraform)

This directory contains Terraform configurations to set up an EKS cluster in VPC1 and a Network Load Balancer (NLB) in VPC2 for a cross-VPC load balancing scenario.

## Components

The Terraform configuration creates:

1. **EKS Cluster in VPC1**:
   - Kubernetes version 1.29 (configurable)
   - Public and private endpoint access
   - Node group with t3.medium instances (configurable)
   - Uses the security group created during VPC peering setup

2. **Network Load Balancer in VPC2**:
   - Internet-facing NLB
   - TCP listener on port 80
   - Target group with IP target type
   - Health checks configured

## Prerequisites

- Terraform >= 1.0.0
- AWS CLI configured with appropriate permissions
- AWS provider >= 4.0.0
- VPC peering setup completed (see ../vpc-peering/)

## Usage

1. First, apply the VPC peering Terraform configuration:
   ```bash
   cd ../vpc-peering
   terraform init
   terraform apply
   cd ../eks-nlb
   ```

2. Initialize Terraform:
   ```bash
   terraform init
   ```

3. Review the configuration:
   ```bash
   terraform plan
   ```

4. Apply the configuration:
   ```bash
   terraform apply
   ```

5. To customize the configuration, create a `terraform.tfvars` file based on the example:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your desired values
   ```

## Outputs

The Terraform configuration outputs the following values:

- `cluster_name`: Name of the EKS cluster
- `cluster_endpoint`: Endpoint for EKS control plane
- `cluster_ca_certificate`: Certificate authority data for EKS cluster
- `cluster_role_arn`: ARN of the IAM role for the EKS cluster
- `node_role_arn`: ARN of the IAM role for the EKS nodes
- `target_group_arn`: ARN of the NLB target group
- `nlb_arn`: ARN of the Network Load Balancer
- `nlb_dns`: DNS name of the Network Load Balancer
- `listener_arn`: ARN of the NLB listener

These outputs can be used by other Terraform configurations or scripts to set up the AWS Load Balancer Controller and TargetGroupBinding.

## Accessing the EKS Cluster

After applying the Terraform configuration, update your kubeconfig:

```bash
aws eks update-kubeconfig --name cross-vpc-demo --region us-east-1
```

## Cleanup

To destroy the resources:

```bash
terraform destroy
```

Note: Make sure to destroy any resources created in the EKS cluster before attempting to destroy the cluster itself.
---
# EKS and NLB Setup for Cross-VPC Load Balancing

This directory contains scripts to set up an EKS cluster in VPC1 and a Network Load Balancer (NLB) in VPC2 for a cross-VPC load balancing scenario.

## Components

- **setup-eks.sh**: Creates an EKS cluster in VPC1
- **setup-nlb.sh**: Creates an NLB in VPC2

## Prerequisites

Before running these scripts, you must first set up the VPCs and VPC peering by running the scripts in the `../vpc-peering/` directory.

## Architecture

The setup creates:

1. **EKS Cluster in VPC1**:
   - Kubernetes version 1.29
   - Public and private endpoint access
   - Node group with t3.medium instances
   - Uses the security group created during VPC peering setup

2. **Network Load Balancer in VPC2**:
   - Internet-facing NLB
   - TCP listener on port 80
   - Target group with IP target type
   - Health checks configured

## Usage

1. Make sure you've run the VPC and VPC peering setup scripts first:
   ```bash
   cd ../vpc-peering/
   ./setup-vpcs.sh
   ./setup-vpc-peering.sh
   cd ../eks-nlb/
   ```

2. Run the EKS setup script:
   ```bash
   ./setup-eks.sh
   ```

3. Run the NLB setup script:
   ```bash
   ./setup-nlb.sh
   ```

The scripts will create `eks-config.env` and `nlb-config.env` files with all the resource IDs and configuration details.

## Cleanup

To clean up the resources:

1. Delete the EKS node group:
   ```bash
   aws eks delete-nodegroup --cluster-name cross-vpc-demo --nodegroup-name ng-1
   ```

2. Delete the EKS cluster:
   ```bash
   aws eks delete-cluster --name cross-vpc-demo
   ```

3. Delete the NLB:
   ```bash
   NLB_ARN=$(grep NLB_ARN nlb-config.env | cut -d= -f2)
   aws elbv2 delete-load-balancer --load-balancer-arn $NLB_ARN
   ```

4. Delete the target group:
   ```bash
   TG_ARN=$(grep TARGET_GROUP_ARN nlb-config.env | cut -d= -f2)
   aws elbv2 delete-target-group --target-group-arn $TG_ARN
   ```

5. Delete the IAM roles:
   ```bash
   aws iam detach-role-policy --role-name eks-cluster-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
   aws iam delete-role --role-name eks-cluster-role

   aws iam detach-role-policy --role-name eks-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
   aws iam detach-role-policy --role-name eks-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
   aws iam detach-role-policy --role-name eks-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
   aws iam delete-role --role-name eks-node-role
   ```

Note: Make sure to delete any resources created in the EKS cluster before attempting to delete the cluster itself.
