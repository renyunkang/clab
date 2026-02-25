echo "====== docker ======"
curl -fsSL https://get.docker.com | bash
# curl -fsSL https://get.docker.com | bash -s docker  --version 24.0

echo "====== kind ======"
# For AMD64 / x86_64
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-amd64
# For ARM64
[ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.31.0/kind-linux-arm64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

echo "====== clab ======"
bash -c "$(curl -sL https://get.containerlab.dev)"

echo "====== kubectl ======"
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

echo "====== helm ======"
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
