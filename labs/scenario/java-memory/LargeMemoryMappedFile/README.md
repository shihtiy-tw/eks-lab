# README

## Setup

### Build IMAGE

```bash
ecr-build.sh java-largememorymappedfile us-east-1
```

### Deployment

```bash
export IMAGE="$(aws ecr describe-repositories --repository-names java-largememorymappedfile | jq -r '.repositories[0].repositoryUri'):latest"
envsubst < k8s-deployment-java-largememorymappedfile.yaml | kubectl apply -f -
```

## Analyze
