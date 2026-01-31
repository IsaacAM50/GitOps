#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

echo_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ ! -f ".env.example" ]; then
    echo_error "Ejecuta desde la raíz del proyecto"
    exit 1
fi

echo ""
echo "=== 1. PRERREQUISITOS ==="

for cmd in docker kubectl minikube git python3 node kubeseal; do
    if ! command -v $cmd &> /dev/null; then
        echo_error "$cmd no instalado"
        exit 1
    fi
done

echo ""
echo "=== 2. VARIABLES ==="

if [ ! -f ".env" ]; then
    cp .env.example .env
    echo_warn "Archivo .env creado. Edítalo."
    read -p "¿Editar .env ahora? (y/n): " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    fi
fi

source .env

GITHUB_USERNAME=${GITHUB_USERNAME:-"isaac-adams"}
GITOPS_REPO_NAME=${GITOPS_REPO_NAME:-"GitOps-Manifests"}

echo ""
echo "=== 3. MINIKUBE ==="

if minikube status &> /dev/null; then
    read -p "Minikube corriendo. ¿Reiniciar? (y/n): " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        minikube stop
        minikube delete
        minikube start --cpus=4 --memory=2200 --driver=docker
    fi
else
    minikube start --cpus=4 --memory=2200 --driver=docker
fi

echo ""
echo "=== 4. INSTALAR ARGOCD Y SEALED SECRETS ==="

kubectl create namespace argocd 2>/dev/null || true

kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

echo "Esperando ArgoCD..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd 2>/dev/null || true

echo "Esperando Sealed Secrets..."
kubectl wait --for=condition=available --timeout=180s deployment/sealed-secrets-controller -n kube-system 2>/dev/null || true

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "admin")

echo ""
echo "ArgoCD: https://localhost:8080"
echo "Usuario: admin"
echo "Password: $ARGOCD_PASSWORD"

kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > sealed-secrets-pub-cert.pem 2>/dev/null || echo_warn "No se pudo obtener certificado"

echo ""
echo "=== 5. CREAR SECRETS ==="

kubectl create namespace gitops-app 2>/dev/null || true

TEMP_FILE=$(mktemp)

cat > $TEMP_FILE <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tokens-secrets
  namespace: gitops-app
type: Opaque
data:
  circleci-token: $(echo -n "$CIRCLECI_TOKEN" | base64)
  github-token: $(echo -n "$GITHUB_TOKEN" | base64)
EOF

kubeseal --scope cluster-wide \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml < $TEMP_FILE | kubectl apply -f -

rm $TEMP_FILE

echo ""
echo "Sealed Secret creado. Para el repositorio:"

TEMP_FILE2=$(mktemp)
cat > $TEMP_FILE2 <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: tokens-secrets
  namespace: gitops-app
type: Opaque
data:
  circleci-token: $(echo -n "$CIRCLECI_TOKEN" | base64)
  github-token: $(echo -n "$GITHUB_TOKEN" | base64)
EOF

kubeseal --scope cluster-wide \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml < $TEMP_FILE2

rm $TEMP_FILE2

echo ""
echo "=== 6. CONFIGURAR ARGOCD ==="

cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: gitops-platform
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/${GITHUB_USERNAME}/${GITOPS_REPO_NAME}.git
    targetRevision: main
    path: kubernetes
  destination:
    server: https://kubernetes.default.svc
    namespace: gitops-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

echo ""
echo "=== 7. PORT FORWARDING ==="

pkill -f "port-forward.*argocd-server" 2>/dev/null || true
pkill -f "port-forward.*gitops-backend" 2>/dev/null || true
pkill -f "port-forward.*gitops-frontend" 2>/dev/null || true

kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo "ArgoCD: https://localhost:8080"

if kubectl get deployment gitops-backend -n gitops-app &> /dev/null; then
    kubectl port-forward svc/gitops-backend-service -n gitops-app 8000:8000 > /dev/null 2>&1 &
    echo "Backend: http://localhost:8000"
fi

if kubectl get deployment gitops-frontend -n gitops-app &> /dev/null; then
    kubectl port-forward svc/gitops-frontend-service -n gitops-app 3000:3000 > /dev/null 2>&1 &
    echo "Frontend: http://localhost:3000"
fi

echo ""
echo "=== COMPLETADO ==="
echo "ArgoCD: https://localhost:8080"
echo "Usuario: admin"
echo "Password: $ARGOCD_PASSWORD"
echo ""
echo "Certificado: sealed-secrets-pub-cert.pem"
echo "Para crear secrets offline:"
echo "kubeseal --cert sealed-secrets-pub-cert.pem -o yaml < secret.yaml > sealed-secret.yaml"