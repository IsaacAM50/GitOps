#!/bin/bash

#############################################################################
# GitOps Platform - Setup Completo
# 
# Este script automatiza la configuración completa del proyecto:
# 1. Verifica prerrequisitos
# 2. Configura Minikube
# 3. Instala ArgoCD
# 4. Despliega la aplicación
# 5. Configura port-forwarding
#
# Uso: ./setup-complete.sh
#############################################################################

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        GitOps Platform - Instalación Automatizada             ║
║                                                                ║
║  Este script configurará todo el entorno necesario para        ║
║  ejecutar el proyecto GitOps Platform.                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Funciones de logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Verificar que estamos en el directorio correcto
if [ ! -f ".env.example" ]; then
    log_error "Debes ejecutar este script desde la raíz del proyecto"
    exit 1
fi

#############################################################################
# PASO 1: Verificación de Prerrequisitos
#############################################################################

log_step "PASO 1: Verificando Prerrequisitos"

check_command() {
    if command -v $1 &> /dev/null; then
        log_success "$1 está instalado"
        return 0
    else
        log_error "$1 no está instalado"
        return 1
    fi
}

MISSING_DEPS=0

check_command docker || MISSING_DEPS=$((MISSING_DEPS + 1))
check_command kubectl || MISSING_DEPS=$((MISSING_DEPS + 1))
check_command minikube || MISSING_DEPS=$((MISSING_DEPS + 1))
check_command git || MISSING_DEPS=$((MISSING_DEPS + 1))
check_command python3 || MISSING_DEPS=$((MISSING_DEPS + 1))
check_command node || MISSING_DEPS=$((MISSING_DEPS + 1))

if [ $MISSING_DEPS -gt 0 ]; then
    log_error "Faltan $MISSING_DEPS dependencias. Por favor instálalas antes de continuar."
    echo ""
    echo "Instalación rápida (macOS con Homebrew):"
    echo "  brew install docker kubectl minikube git python node"
    echo ""
    echo "Instalación rápida (Ubuntu/Debian):"
    echo "  sudo apt-get install docker.io kubectl git python3 nodejs npm"
    echo "  curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
    echo "  sudo install minikube-linux-amd64 /usr/local/bin/minikube"
    exit 1
fi

#############################################################################
# PASO 2: Configuración de Variables de Entorno
#############################################################################

log_step "PASO 2: Configurando Variables de Entorno"

if [ ! -f ".env" ]; then
    log_warning "Archivo .env no encontrado, creando desde .env.example..."
    cp .env.example .env
    log_success ".env creado"
    echo ""
    log_warning "⚠️  IMPORTANTE: Edita el archivo .env con tus valores reales"
    log_info "Necesitas configurar:"
    echo "  - CIRCLECI_TOKEN: Token de CircleCI"
    echo "  - GITHUB_USERNAME: Tu usuario de GitHub"
    echo "  - GITHUB_TOKEN: Token de GitHub con scopes repo y write:packages"
    echo "  - GITOPS_REPO_NAME: Nombre de tu repo de manifests"
    echo ""
    read -p "¿Quieres editar el .env ahora? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ${EDITOR:-nano} .env
    else
        log_warning "Recuerda editar .env antes de hacer deployments reales"
    fi
else
    log_success ".env ya existe"
fi

# Cargar variables de entorno
set -a
source .env
set +a

# Verificar variables críticas
if [ -z "$GITHUB_USERNAME" ] || [ "$GITHUB_USERNAME" == "isaac-adams" ]; then
    log_warning "GITHUB_USERNAME no está configurado o usa el valor de ejemplo"
fi

if [ -z "$CIRCLECI_TOKEN" ] || [ "$CIRCLECI_TOKEN" == "your_circleci_personal_api_token_here" ]; then
    log_warning "CIRCLECI_TOKEN no está configurado"
fi

#############################################################################
# PASO 3: Configuración de Minikube
#############################################################################

log_step "PASO 3: Configurando Minikube"

# Verificar si Minikube ya está corriendo
if minikube status &> /dev/null; then
    log_info "Minikube ya está corriendo"
    read -p "¿Quieres reiniciar Minikube? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deteniendo Minikube..."
        minikube stop
        log_info "Eliminando cluster..."
        minikube delete
        log_info "Iniciando nuevo cluster..."
        minikube start --cpus=4 --memory=8192 --driver=docker
    fi
else
    log_info "Iniciando Minikube..."
    minikube start --cpus=4 --memory=8192 --driver=docker
fi

log_success "Minikube está listo"

# Verificar cluster
log_info "Verificando cluster..."
kubectl cluster-info
kubectl get nodes

#############################################################################
# PASO 4: Instalación de ArgoCD
#############################################################################

log_step "PASO 4: Instalando ArgoCD"

# Crear namespace si no existe
if ! kubectl get namespace argocd &> /dev/null; then
    log_info "Creando namespace argocd..."
    kubectl create namespace argocd
    log_success "Namespace argocd creado"
else
    log_info "Namespace argocd ya existe"
fi

# Instalar ArgoCD
log_info "Instalando ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Esperar a que ArgoCD esté listo
log_info "Esperando a que ArgoCD esté listo (esto puede tomar 2-3 minutos)..."
kubectl wait --for=condition=available --timeout=300s \
    deployment/argocd-server -n argocd

log_success "ArgoCD instalado correctamente"

# Obtener password inicial
log_info "Obteniendo password de ArgoCD..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
    -o jsonpath="{.data.password}" | base64 -d)

echo ""
log_success "Credenciales de ArgoCD:"
echo -e "  URL:      ${GREEN}https://localhost:8080${NC}"
echo -e "  Usuario:  ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"
echo ""

#############################################################################
# PASO 5: Creación de Namespace y Secrets
#############################################################################

log_step "PASO 5: Configurando Namespace y Secrets"

# Crear namespace para la aplicación
if ! kubectl get namespace gitops-app &> /dev/null; then
    log_info "Creando namespace gitops-app..."
    kubectl create namespace gitops-app
    log_success "Namespace gitops-app creado"
else
    log_info "Namespace gitops-app ya existe"
fi

# Crear secrets si las variables están configuradas
if [ -n "$CIRCLECI_TOKEN" ] && [ "$CIRCLECI_TOKEN" != "your_circleci_personal_api_token_here" ]; then
    log_info "Creando secrets..."
    kubectl create secret generic app-secrets \
        --namespace=gitops-app \
        --from-literal=circleci-token="${CIRCLECI_TOKEN}" \
        --from-literal=github-token="${GITHUB_TOKEN}" \
        --from-literal=api-key="demo-key" \
        --dry-run=client -o yaml | kubectl apply -f -
    log_success "Secrets creados"
else
    log_warning "Tokens no configurados, saltando creación de secrets"
    log_info "Puedes crearlos manualmente después con:"
    echo "  kubectl create secret generic app-secrets \\"
    echo "    --namespace=gitops-app \\"
    echo "    --from-literal=circleci-token=\$CIRCLECI_TOKEN \\"
    echo "    --from-literal=github-token=\$GITHUB_TOKEN"
fi

#############################################################################
# PASO 6: Configuración de ArgoCD Application
#############################################################################

log_step "PASO 6: Configurando ArgoCD Application"

# Verificar que GITHUB_USERNAME está configurado
if [ -z "$GITHUB_USERNAME" ] || [ "$GITHUB_USERNAME" == "isaac-adams" ]; then
    log_warning "GITHUB_USERNAME no está configurado correctamente"
    log_info "Usando valor de ejemplo para demostración"
    GITHUB_USERNAME="isaac-adams"
fi

if [ -z "$GITOPS_REPO_NAME" ]; then
    GITOPS_REPO_NAME="GitOps-Manifests"
fi

log_info "Configurando ArgoCD Application..."
log_info "Repository: https://github.com/${GITHUB_USERNAME}/${GITOPS_REPO_NAME}.git"

# Crear ArgoCD Application
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

log_success "ArgoCD Application configurada"

# Esperar sincronización inicial
log_info "Esperando sincronización inicial de ArgoCD..."
sleep 10

#############################################################################
# PASO 7: Port Forwarding
#############################################################################

log_step "PASO 7: Configurando Port Forwarding"

# Función para matar port-forwards existentes
cleanup_port_forwards() {
    pkill -f "port-forward.*argocd-server" 2>/dev/null || true
    pkill -f "port-forward.*gitops-backend" 2>/dev/null || true
    pkill -f "port-forward.*gitops-frontend" 2>/dev/null || true
}

cleanup_port_forwards

# ArgoCD
log_info "Iniciando port-forward para ArgoCD..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 > /dev/null 2>&1 &
ARGOCD_PF_PID=$!
log_success "ArgoCD disponible en https://localhost:8080 (PID: $ARGOCD_PF_PID)"

# Esperar a que los pods estén listos
log_info "Esperando a que los pods de la aplicación estén listos..."
sleep 5

# Verificar si los pods existen antes de hacer port-forward
if kubectl get deployment gitops-backend -n gitops-app &> /dev/null; then
    # Backend
    log_info "Iniciando port-forward para Backend..."
    kubectl port-forward svc/gitops-backend-service -n gitops-app 8000:8000 > /dev/null 2>&1 &
    BACKEND_PF_PID=$!
    log_success "Backend disponible en http://localhost:8000 (PID: $BACKEND_PF_PID)"
else
    log_warning "Deployment gitops-backend no encontrado (esperado si es primera instalación)"
fi

if kubectl get deployment gitops-frontend -n gitops-app &> /dev/null; then
    # Frontend
    log_info "Iniciando port-forward para Frontend..."
    kubectl port-forward svc/gitops-frontend-service -n gitops-app 3000:3000 > /dev/null 2>&1 &
    FRONTEND_PF_PID=$!
    log_success "Frontend disponible en http://localhost:3000 (PID: $FRONTEND_PF_PID)"
else
    log_warning "Deployment gitops-frontend no encontrado (esperado si es primera instalación)"
fi

#############################################################################
# PASO 8: Verificación Final
#############################################################################

log_step "PASO 8: Verificación Final"

log_info "Estado del cluster:"
kubectl get all -n gitops-app

echo ""
log_info "Estado de ArgoCD:"
kubectl get applications -n argocd

#############################################################################
# RESUMEN FINAL
#############################################################################

echo ""
echo -e "${PURPLE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║                    INSTALACIÓN COMPLETA                        ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ Servicios Disponibles:${NC}"
echo ""
echo -e "  ${CYAN}ArgoCD UI:${NC}        https://localhost:8080"
echo -e "  ${CYAN}Usuario:${NC}          admin"
echo -e "  ${CYAN}Password:${NC}         ${ARGOCD_PASSWORD}"
echo ""

if kubectl get deployment gitops-backend -n gitops-app &> /dev/null; then
    echo -e "  ${CYAN}Backend API:${NC}      http://localhost:8000"
    echo -e "  ${CYAN}API Docs:${NC}         http://localhost:8000/docs"
    echo ""
fi

if kubectl get deployment gitops-frontend -n gitops-app &> /dev/null; then
    echo -e "  ${CYAN}Frontend App:${NC}     http://localhost:3000"
    echo ""
fi

echo -e "${GREEN}✓ Comandos Útiles:${NC}"
echo ""
echo -e "  ${CYAN}Ver pods:${NC}"
echo "    kubectl get pods -n gitops-app"
echo ""
echo -e "  ${CYAN}Ver logs del backend:${NC}"
echo "    kubectl logs -f deployment/gitops-backend -n gitops-app"
echo ""
echo -e "  ${CYAN}Ver logs del frontend:${NC}"
echo "    kubectl logs -f deployment/gitops-frontend -n gitops-app"
echo ""
echo -e "  ${CYAN}Estado de ArgoCD:${NC}"
echo "    kubectl get applications -n argocd"
echo ""
echo -e "  ${CYAN}Reiniciar ArgoCD sync:${NC}"
echo "    kubectl delete application gitops-platform -n argocd"
echo "    ./setup-complete.sh"
echo ""

echo -e "${YELLOW}⚠️  Notas Importantes:${NC}"
echo ""
echo "1. Los port-forwards se ejecutan en background"
echo "   Para detenerlos: pkill -f port-forward"
echo ""
echo "2. Si los deployments no aparecen, verifica que:"
echo "   - El repo de manifests existe en GitHub"
echo "   - La URL en ArgoCD Application es correcta"
echo "   - Los manifests están en la carpeta 'kubernetes/'"
echo ""
echo "3. Para desarrollo local (sin Kubernetes):"
echo "   ./scripts/dev.sh"
echo ""

# Guardar PIDs para cleanup
cat > /tmp/gitops-pids.txt <<EOF
ARGOCD_PF_PID=${ARGOCD_PF_PID}
BACKEND_PF_PID=${BACKEND_PF_PID}
FRONTEND_PF_PID=${FRONTEND_PF_PID}
EOF

log_success "Setup completo! 🚀"
echo ""