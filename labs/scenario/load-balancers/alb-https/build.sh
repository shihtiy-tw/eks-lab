#!/bin/bash

# $ ./build.sh
# $ kustomize build . | kubectl delete -f -

#!/bin/bash

# Get the service name from the k8s-service.yaml file
SERVICE_NAME=$(yq -r ".metadata.name" k8s-service.yaml)
echo "SERVICE_NAME: $SERVICE_NAME"

# Get the name prefix from the kustomization.yaml file
NAME_PREFIX=$(yq -r ".namePrefix" kustomization.yaml)
echo "NAME_PREFIX: $NAME_PREFIX"

# Apply the Terraform configuration
terraform -chdir=./terraform apply

# Get the ACM certificate ARN from the Terraform output
ACM_CERT_ARN=$(terraform -chdir=terraform output acm_certificate_arn)
echo "ACM_CERT_ARN: $ACM_CERT_ARN"

# Get the Route53 zone ID from the Terraform output
ZONE_ID=$(terraform -chdir=terraform output -raw route53_zone_id)
echo "ZONE_ID: $ZONE_ID"

# Get the hosted zone name using the Route53 zone ID
HOSTED_ZONE_NAME=$(aws route53 get-hosted-zone --id "$ZONE_ID" --query 'HostedZone.Name' --output text)
echo "HOSTED_ZONE_NAME: $HOSTED_ZONE_NAME"

# Construct the host name for the ALB
HOST_NAME="alb.$HOSTED_ZONE_NAME"
echo "HOST_NAME: $HOST_NAME"


kustomize build . \
  | sed -e "/annotations:/,/spec:/s/${SERVICE_NAME}/${NAME_PREFIX}${SERVICE_NAME}/g" \
  | sed -e "/annotations:/,/spec:/s~example-certificate-arn~${ACM_CERT_ARN}~g" \
  | sed -e "/annotations:/,/spec:/s/example.com/${HOST_NAME%.*}/g" \
  | sed -e "/args:/,/image:/s/example.com/${HOSTED_ZONE_NAME%.*}/g" \
  | kubectl apply -f -

kubectl logs -f "$(kubectl get po | grep -E -o 'external-dns[A-Za-z0-9-]+')"

