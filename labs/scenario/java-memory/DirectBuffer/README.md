# README

## Setup

### Build IMAGE

```bash
ecr-build.sh java-directbuffer us-east-1
```

### Deployment

```bash
export IMAGE="$(aws ecr describe-repositories --repository-names java-directbuffer | jq -r '.repositories[0].repositoryUri'):latest"
envsubst < k8s-deployment-java-directbuffer.yaml | kubectl apply -f -
```

## Analyze
