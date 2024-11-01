# Fargate NGINX Logging

## Destination

- Cloudwatch
- Opensearch

### OpenSearch

#### Configmap for fluentbit

```yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: aws-logging
  namespace: aws-observability
data:
  output.conf: |-
    [OUTPUT]
      Name  es
      Match *
      Host  $HOST
      Port  443
      Index $INDEX
      Type  $TYPE
      AWS_Auth On
      AWS_Region $REGION
      tls   On
      Suppress_Type_Name On
```

`Suppress_Type_Name` is reqired. See [Elasticsearch | Fluent Bit: Official Manual](https://docs.fluentbit.io/manual/pipeline/outputs/elasticsearch#action-metadata-contains-an-unknown-parameter-type).

#### Connect to Opensearch Dashboard

To connect to opensearch dashboard in vpc, we can use ssh tunnel to achieve it:

```sh
ssh username@bastion -N -L 9200:<es domain>:443
```

Ref:
- [Use SSH tunnel to access OpenSearch Dashboards | AWS re:Post](https://repost.aws/knowledge-center/opensearch-outside-vpc-ssh)
