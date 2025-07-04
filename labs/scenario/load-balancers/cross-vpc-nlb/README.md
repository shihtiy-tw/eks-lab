# Cross-VPC Network Load Balancer Scenario

This scenario demonstrates how to use the AWS Load Balancer Controller to register EKS pods with a Network Load Balancer (NLB) in a different VPC.

## Architecture

This setup creates:

1. An EKS cluster in VPC1
2. A Network Load Balancer in VPC2
3. VPC peering between VPC1 and VPC2
4. AWS Load Balancer Controller configured to use VPC2
5. A TargetGroupBinding to register pod IPs with the NLB in VPC2

## Prerequisites

Before running this scenario, you need to set up the infrastructure using Terraform:

1. Create the VPCs and VPC peering:
   ```bash
   cd /home/ubuntu/eks-lab/labs/resources/cross-vpc-loadbalancing/vpc-peering
   terraform init
   terraform apply
   ```

2. Create the EKS cluster and NLB:
   ```bash
   cd ../eks-nlb
   terraform init
   terraform apply
   ```

3. Configure kubectl to use the EKS cluster:
   ```bash
   aws eks update-kubeconfig --name $(terraform output -raw cluster_name) --region $(terraform output -raw region)
   ```

## Components

- **k8s-namespace.yaml**: Creates a namespace for the demo
- **k8s-deployment-sample-app.yaml**: Deploys a sample NGINX application
- **k8s-service.yaml**: Creates a ClusterIP service for the application
- **k8s-targetgroupbinding.yaml**: Binds the service to the NLB target group in VPC2
- **k8s-aws-load-balancer-controller-values.yaml**: Configuration for the AWS Load Balancer Controller
- **build.sh**: Script to deploy all components

## Deployment

Run the build script to deploy the scenario:

```bash
./build.sh
```

The script will:
1. Load configuration from Terraform outputs
2. Create the necessary IAM roles and policies
3. Install the AWS Load Balancer Controller with custom VPC configuration
4. Deploy the sample application
5. Create the TargetGroupBinding to register pod IPs with the NLB

## Verification

After deployment, you can access the application using the NLB DNS name provided at the end of the build script.

To verify the TargetGroupBinding:

```bash
kubectl get targetgroupbinding -n cross-vpc-demo
```

To check if targets are registered with the NLB:

```bash
cd /home/ubuntu/eks-lab/labs/resources/cross-vpc-loadbalancing/eks-nlb
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn)
aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN
```

## How It Works

1. The AWS Load Balancer Controller is configured to use VPC2 instead of the EKS cluster's VPC
2. The TargetGroupBinding resource tells the controller to register pod IPs with the target group
3. Traffic flows from the internet to the NLB in VPC2
4. The NLB forwards traffic to pod IPs in VPC1 via the VPC peering connection
5. Return traffic flows back through the same path

## Cleanup

To clean up the resources:

1. Delete the Kubernetes resources:
   ```bash
   kubectl delete -f k8s-targetgroupbinding.yaml
   kubectl delete -f k8s-service.yaml
   kubectl delete -f k8s-deployment-sample-app.yaml
   kubectl delete -f k8s-namespace.yaml
   ```

2. Uninstall the AWS Load Balancer Controller:
   ```bash
   helm uninstall aws-load-balancer-controller -n kube-system
   ```

3. Delete the EKS cluster and NLB:
   ```bash
   cd /home/ubuntu/eks-lab/labs/resources/cross-vpc-loadbalancing/eks-nlb
   terraform destroy
   ```

4. Delete the VPCs and VPC peering:
   ```bash
   cd ../vpc-peering
   terraform destroy
   ```
