# Toolkit for EKS

- eksctl
- kubectl
- helm
- awscli

## eksctl

[Installation - eksctl](https://eksctl.io/installation/)

```sh
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo mv /tmp/eksctl /usr/local/bin
```

## kubectl

[Install or update kubectl](https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html#kubectl-install-update).

```sh
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.2/2024-07-12/bin/linux/amd64/kubectl
chmod +x ./kubectl
cp kubectl $HOME/.local/bin/
```

## helm

[Deploy applications with Helm on Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/helm.html)

```sh
curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

rm get_helm.sh
```

## awscli

```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

$ rm -rf aws awscliv2.zip
```

## ECR Builder

```bash
curl -O https://gist.githubusercontent.com/shihtiy-tw/538624de9f45b717a4226b155c4706f5/raw/8f032e10499dfb4472c2727928d65c6438e3797b/ecr-builder.sh

chmod a+x ecr-builder.sh

sudo mv ecr-builder.sh /usr/local/bin
```
