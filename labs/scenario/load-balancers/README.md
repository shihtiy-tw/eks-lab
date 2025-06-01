# EKS Load Balancer Scenarios

This directory contains examples of different load balancing configurations for Amazon EKS. These scenarios demonstrate how to implement various load balancing patterns using AWS Application Load Balancer (ALB) and Network Load Balancer (NLB).

## Prerequisites

Before running these scenarios, ensure you have:

1. A running EKS cluster
2. The [AWS Load Balancer Controller](../../integrations/aws-load-balancer-controller/) installed
3. Appropriate IAM permissions for creating load balancer resources
4. For HTTPS scenarios, a valid SSL/TLS certificate in AWS Certificate Manager (ACM)

## Available Scenarios

| Scenario | Description | Key Features |
|----------|-------------|-------------|
| [ALB with HTTPS](./alb-https/) | Basic HTTPS configuration with ALB | TLS termination, ACM integration |
| [ALB Hostname Routing](./alb-hostname-routing/) | Route traffic based on hostnames | Host-based routing rules |
| [ALB Graceful Shutdown](./alb-graceful-shutdown/) | Implement graceful pod termination | Connection draining, preStop hooks |
| [ALB Listener Port](./alb-listener-port/) | Custom listener port configuration | Non-standard ports |
| [ALB Listener Rule](./alb-listener-rule/) | Advanced routing with listener rules | Path-based routing, header-based routing |
| [ALB mTLS](./alb-mtls/) | Mutual TLS authentication | Client certificate validation |
| [NLB General](./nlb-general/) | Basic NLB configuration | TCP/UDP load balancing |

## Usage

Each scenario directory contains:

- A `build.sh` script for deployment
- Kubernetes manifest files
- Specific documentation for the scenario

To deploy a scenario:

```bash
cd <scenario-directory>
./build.sh
```

For example:

```bash
cd alb-https
./build.sh
```

## Implementation Details

### ALB with HTTPS

This scenario demonstrates how to:
- Configure an ALB Ingress with HTTPS
- Use AWS Certificate Manager for TLS termination
- Set up security groups and target groups

### ALB Hostname Routing

This scenario shows how to:
- Route traffic to different services based on hostnames
- Configure host-based routing rules in the Ingress resource
- Support multiple domains on a single ALB

### NLB General

This scenario covers:
- Setting up a Network Load Balancer for TCP/UDP traffic
- Configuring the LoadBalancer service type
- Managing health checks and target groups

## Terraform Examples

Some scenarios include Terraform configurations for infrastructure provisioning. To use these:

```bash
cd <scenario-directory>/terraform
terraform init
terraform apply
```

## Troubleshooting

If you encounter issues:

1. Check the AWS Load Balancer Controller logs:
   ```
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

2. Verify that the Ingress resource is properly configured:
   ```
   kubectl describe ingress <ingress-name>
   ```

3. Check the AWS Console for load balancer configuration and health
