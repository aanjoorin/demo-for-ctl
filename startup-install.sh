#!/bin/bash

## INSTALL AWS CLI
apt update -y
apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version

## INSTALL HELM
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

## INSTALL KUBECTL 
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# Configure Autocomplete
apt-get install -y bash-completion 
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc

# INSTALL DOCKER
sudo apt-get -y install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get -y install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

## INSTALL KIND
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create KIND cluster
kind create cluster --config /tmp/kind-config.yaml

# Sleep to ensure cluster is ready
sleep 30

## INSTALL GH ARC

# 1. Create GH Token Secret
kubectl create namespace "${runner_set_namespace}"
kubectl create secret generic github-token --from-literal github_token="${github_token}" --namespace "${runner_set_namespace}"

# 2. Install runner set controller
helm install arc --namespace "${controller_namespace}" --create-namespace oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller

# 3. Install Runner Scale Set
helm install arc-runner-set --namespace "${runner_set_namespace}" --create-namespace --set githubConfigUrl="${github_config_url}" --set githubConfigSecret=github-token --set containerMode.type=dind --set template.spec.containers[0].name=runner --set template.spec.containers[0].image="${runner_image}" --set template.spec.containers[0].command={"/home/runner/run.sh"} oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set

