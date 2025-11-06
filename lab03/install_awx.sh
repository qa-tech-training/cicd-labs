#!/usr/bin/env bash
# install_awx_kind_3node.sh
# 3-node KinD + AWX Operator + AWX (NodePort) on Ubuntu. AWX at http://<VM_PUBLIC_IP>:30080
set -euo pipefail

AWX_NAMESPACE="awx"
OPERATOR_TAG="2.19.1"           # change if you need a different operator release
AWX_ADMIN_USER="admin"
AWX_ADMIN_PASS="ChangeMe123!"   # CHANGE for anything beyond a quick demo
HTTP_NODEPORT="30080"
HTTPS_NODEPORT="30443"          # unused by default

echo "[1/10] Install Docker & basics..."
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release jq
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
fi
# ensure user can talk to docker now (no relogin)
if ! groups | grep -qw docker; then
  sudo usermod -aG docker "root"
fi
if ! docker ps >/dev/null 2>&1; then
  exec sg docker -c "$0"  # re-exec inside docker group
fi

echo "[2/10] Install kubectl (if needed)..."
if ! command -v kubectl >/dev/null 2>&1; then
  curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -m 0755 kubectl /usr/local/bin/kubectl
  rm kubectl
fi

echo "[3/10] Install KinD (if needed)..."
if ! command -v kind >/dev/null 2>&1; then
  curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64"
  chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind
fi

echo "[4/10] Create 3-node KinD cluster (1 control-plane + 2 workers) with host port mappings..."
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  # Map host ports -> cluster to expose AWX easily
  extraPortMappings:
  - containerPort: ${HTTP_NODEPORT}
    hostPort: ${HTTP_NODEPORT}
    protocol: TCP
  - containerPort: ${HTTPS_NODEPORT}
    hostPort: ${HTTPS_NODEPORT}
    protocol: TCP
- role: worker
- role: worker
EOF

if ! kind get clusters 2>/dev/null | grep -q '^awx-kind$'; then
  kind create cluster --name awx-kind --config kind-config.yaml
else
  echo "[*] KinD cluster 'awx-kind' already exists, skipping creation."
fi
kubectl cluster-info --context kind-awx-kind >/dev/null

echo "[5/10] Install local-path-provisioner & make it default StorageClass..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml
# Kind’s default SC may be 'standard' or 'local-path'; ensure local-path is default:
kubectl annotate sc local-path storageclass.kubernetes.io/is-default-class=true --overwrite || true

echo "[6/10] Create namespace '${AWX_NAMESPACE}'..."
kubectl create namespace "${AWX_NAMESPACE}" >/dev/null 2>&1 || true

echo "[7/10] Install AWX Operator (tag: ${OPERATOR_TAG})..."
kubectl apply -k "https://github.com/ansible/awx-operator/config/default?ref=${OPERATOR_TAG}" -n "${AWX_NAMESPACE}"
kubectl -n "${AWX_NAMESPACE}" rollout status deploy/awx-operator-controller-manager --timeout=300s

echo "[8/10] Create/refresh admin password secret..."
kubectl -n "${AWX_NAMESPACE}" delete secret awx-admin >/dev/null 2>&1 || true
kubectl -n "${AWX_NAMESPACE}" create secret generic awx-admin --from-literal=password="${AWX_ADMIN_PASS}"

echo "[9/10] Apply a MINIMAL AWX custom resource (compatible across operator versions)..."
cat > awx.yaml <<EOF
apiVersion: awx.ansible.com/v1beta1
kind: AWX
metadata:
  name: awx
spec:
  admin_user: ${AWX_ADMIN_USER}
  admin_password_secret: awx-admin
  service_type: NodePort
  nodeport_port: ${HTTP_NODEPORT}
EOF

kubectl -n "${AWX_NAMESPACE}" apply -f awx.yaml

echo "[*] Waiting for awx-web deployment to be ready (this can take several minutes)..."
for i in {1..60}; do
  READY=$(kubectl -n "${AWX_NAMESPACE}" get deploy awx-web -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")
  [[ "${READY}" == "1" ]] && break
  sleep 10
  echo -n "."
done
echo ""

echo "[10/10] Cluster state:"
kubectl get nodes -o wide
kubectl -n "${AWX_NAMESPACE}" get pods,svc,pvc

HOST_IP=$(hostname -I | awk '{print $1}')
cat <<EOT

----------------------------------------------------------------
 AWX URL:        http://<YOUR_AWX_VM_PUBLIC_IP>:${HTTP_NODEPORT}
 (VM host IP):   ${HOST_IP}
 Admin user:     ${AWX_ADMIN_USER}
 Admin password: ${AWX_ADMIN_PASS}
 Namespace:      ${AWX_NAMESPACE}
 Kube context:   kind-awx-kind
 Logs:           kubectl -n ${AWX_NAMESPACE} logs deploy/awx-web -f
----------------------------------------------------------------
 NOTES:
 • This is a 3-node KinD cluster (1 CP + 2 workers).
 • Storage fields were omitted to avoid CRD version drift; defaults apply.
 • If you want to tune storage later, run:
     kubectl explain awx.spec
   and only use fields present in your installed CRD.
EOT
