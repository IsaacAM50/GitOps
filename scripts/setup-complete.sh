  #!/bin/bash

#############################################################################
# GitOps Platform - Setup Completo
# 
# Este script automatiza la configuración completa del proyecto
# Uso: ./setup-complete.sh
#############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar directorio
if [ ! -f ".env.example" ]; then
    log_error "Ejecuta desde la raíz del proyecto"
    exit 1
fi

#############################################################################
# PASO 1: Prerrequisitos
#############################################################################
echo ""
echo "=== PASO 1: Verificando Prerrequisitos ==="

check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "$1 no está instalado"
        exit 1
    fi
}

check_command docker
check_command kubectl
check_command minikube
check_command git
check_command python3
check_command node

# Verificar kubeseal
if ! command -v kubeseal &> /dev/null; then
    log_error "kubeseal no está instalado"
    echo "Instala con: brew install kubeseal"
    exit 1
fi

#############################################################################
# PASO 2: Variables de Entorno
#############################################################################
echo ""
echo "=== PASO 2: Variables de Entorno ==="

if [ ! -f ".env" ]; then
    cp .env.example .env
    log_warning "Archivo .env creado. Edítalo con tus valores."
    read -p "¿Editar .env ahora? (y/n): " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    fi
fi

source .env

# Usar valores por defecto si no están configurados
GITHUB_USERNAME=${GITHUB_USERNAME:-"isaac-adams"}
GITOPS_REPO_NAME=${GITOPS_REPO_NAME:-"GitOps-Manifests"}
CIRCLECI_TOKEN=${CIRCLECI_TOKEN:-"dummy-circleci-token"}
GITHUB_TOKEN=${GITHUB_TOKEN:-"dummy-github-token"}

#############################################################################
# PASO 3: Minikube
#############################################################################
echo ""
echo "=== PASO 3: Configurando Minikube ==="

if minikube status &> /dev/null; then
    read -p "Minikube ya está corriendo. ¿Reiniciar? (y/n): " -n 1
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        minikube stop
        minikube delete
        minikube start --cpus=4 --memory=2200 --driver=docker
    fi
else
    minikube start --cpus=4 --memory=2200 --driver=docker
fi

#############################################################################
# PASO 4: Instalar ArgoCD y Sealed Secrets
#############################################################################
echo ""
echo "=== PASO 4: Instalando ArgoCD y Sealed Secrets ==="

# Namespace para ArgoCD
kubectl create namespace argocd 2>/dev/null || true

# Instalar ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Instalar Sealed Secrets
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Esperar
echo "Esperando a que ArgoCD esté listo..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd 2>/dev/null || true

echo "Esperando a que Sealed Secrets esté listo..."
kubectl wait --for=condition=available --timeout=180s deployment/sealed-secrets-controller -n kube-system 2>/dev/null || true

# Password de ArgoCD
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d 2>/dev/null || echo "admin")

echo ""
echo "ArgoCD URL: https://localhost:8080"
echo "Usuario: admin"
echo "Password: $ARGOCD_PASSWORD"

#############################################################################
# PASO 5: Crear Sealed Secret y aplicarlo directamente
#############################################################################
echo ""
echo "=== PASO 5: Creando y aplicando Sealed Secret ==="

# Crear namespace para la aplicación
kubectl create namespace gitops-app 2>/dev/null || true

# Crear archivo temporal para el secret normal
TEMP_FILE=$(mktemp)

# Crear secret YAML con datos en base64
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

# Convertir a SealedSecret y aplicar directamente
echo "Creando SealedSecret en el cluster..."
kubeseal --scope cluster-wide \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  -o yaml < $TEMP_FILE | kubectl apply -f -

# Verificar que se creó
sleep 2
echo "Verificando SealedSecret creado..."
kubectl get sealedsecrets -n gitops-app

# Verificar que se desencriptó
sleep 3
echo "Verificando secret desencriptado..."
kubectl get secrets -n gitops-app

# Limpiar archivo temporal
rm $TEMP_FILE

# Mostrar el SealedSecret para copiar al repositorio
echo ""
echo "=== SEALED SECRET PARA EL REPOSITORIO ==="
echo "Si quieres añadirlo a tu repositorio, copia esto:"
echo ""

# Recrear temporalmente para mostrarlo
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
echo "=== FIN DEL SEALED SECRET ==="
echo ""

#############################################################################
# PASO 6: Configurar ArgoCD Application
#############################################################################
echo ""
echo "=== PASO 6: Configurando ArgoCD Application ==="

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

echo "ArgoCD Application creada"

#############################################################################
# PASO 7: Esperar sincronización (pero no indefinidamente)
#############################################################################
echo ""
echo "=== PASO 7: Esperando sincronización inicial ==="

echo "Esperando 10 segundos para que ArgoCD empiece..."
sleep 10

# Verificar estado una sola vez
APP_STATUS=$(kubectl get application gitops-platform -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
HEALTH_STATUS=$(kubectl get application gitops-platform -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")

echo "Estado de sincronización: $APP_STATUS"
echo "Estado de salud: $HEALTH_STATUS"

echo ""
echo "Nota: La sincronización completa puede fallar si tu repositorio no tiene los manifests."
echo "Esto es normal en la primera ejecución."

#############################################################################
# PASO 8: Port Forwarding
#############################################################################
echo ""
echo "=== PASO 8: Configurando Port Forwarding ==="

# Limpiar port-forwards anteriores
pkill -f "port-forward.*argocd-server" 2>/dev/null || true
pkill -f "port-forward.*gitops-backend" 2>/dev/null || true
pkill -f "port-forward.*gitops-frontend" 2>/dev/null || true

# ArgoCD
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
echo "ArgoCD: https://localhost:8080"



#############################################################################
# PASO 9: Verificación final
#############################################################################
echo ""
echo "=== PASO 9: Verificación ==="

echo "1. Pods en gitops-app:"
kubectl get pods -n gitops-app 2>/dev/null || echo "  No hay pods aún (normal si es primera vez)"

echo ""
echo "2. Sealed Secrets en gitops-app:"
kubectl get sealedsecrets -n gitops-app 2>/dev/null || echo "  No hay Sealed Secrets"

echo ""
echo "3. Secrets desencriptados:"
kubectl get secrets -n gitops-app 2>/dev/null | grep -v "default-token" || echo "  No hay secrets adicionales"

echo ""
echo "4. Estado de ArgoCD:"
kubectl get applications -n argocd

echo ""
echo "=== SETUP COMPLETADO ==="
echo ""
echo "Resumen:"
echo "✓ ArgoCD: https://localhost:8080 (admin / $ARGOCD_PASSWORD)"
echo "✓ Sealed Secret creado y aplicado en el cluster"
echo "✓ Namespace gitops-app creado"
echo "✓ ArgoCD Application configurada"
echo ""
echo "Siguientes pasos:"
echo "1. Si el repositorio ${GITHUB_USERNAME}/${GITOPS_REPO_NAME} tiene manifests:"
echo "   - ArgoCD los sincronizará automáticamente"
echo "2. Si no tiene manifests:"
echo "   - Añade tus manifests al repositorio"
echo "   - O usa los del ejemplo"
echo "3. El Sealed Secret ya está en el cluster"
echo "   - Puedes copiarlo de arriba a tu repositorio si quieres"
echo "4. Si los pods estan activos ya puedes hacer port-forwarding "
echo "  - Ya está configurado en este script ./scripts/port-forward.sh"