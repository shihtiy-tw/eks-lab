# Environment Variables
# Get the current context and extract information
CURRENT_CONTEXT=$(kubectl config current-context)
EKS_CLUSTER_NAME=$(echo "$CURRENT_CONTEXT" | awk -F: '{split($NF,a,"/"); print a[2]}')
AWS_REGION=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $4}')
AWS_ACCOUNT_ID=$(echo "$CURRENT_CONTEXT" | awk -F: '{print $5}')
POLICY_NAME="AppMesh-sample-policy"

echo "[debug] create iam policy for sample scenario"
sed -e 's/{{ REGION }}/'"$AWS_REGION"'/g' -e 's/{{ AWS_ACCOUNT_ID }}/'"$AWS_ACCOUNT_ID"'/g' proxy-auth-template.json > proxy-auth.json
aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://proxy-auth.json

kubectl apply -f namespace.yaml

echo "[debug] create servcie account for sample scenario"
eksctl create iamserviceaccount \
    --cluster "$EKS_CLUSTER_NAME" \
    --namespace my-apps \
    --name my-service \
    --attach-policy-arn  arn:aws:iam::"$AWS_ACCOUNT_ID":policy/AppMesh-sample-policy \
    --override-existing-serviceaccounts \
    --approve

rm proxy-auth.json

kubectl apply -f mesh.yaml -f service-a.yaml -f service-b.yaml
