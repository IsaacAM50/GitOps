#!/bin/bash

#############################################################################
# GitOps Platform - Cleanup
# 
# Este script limpia todos los recursos creados por el proyecto
#
# Uso: ./cleanup.sh
#############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

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

# Banner
echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        GitOps Platform - Cleanup                              ║
║                                                                ║
║  Este script eliminará todos los recursos creados             ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo ""
log_warning "Este script eliminará:"
echo "  - Aplicación en ArgoCD"
echo "  - Namespace gitops-app"
echo "  - ArgoCD (opcional)"
echo "  - Minikube cluster (opcional)"
echo "  - Port-forwards activos"
echo "  - Contenedores Docker locales (opcional)"
echo ""

read -p "¿Continuar? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Cancelado"
    exit 0
fi

#############################################################################
# 1. Detener Port-Forwards
#############################################################################

log_info "Deteniendo port-forwards..."
pkill -f "port-forward.*argocd-server" 2>/dev/null || true
pkill -f "port-forward.*gitops-backend" 2>/dev/null || true
pkill -f "port-forward.*gitops-frontend" 2>/dev/null || true
log_success "Port-forwards detenidos"

#############################################################################
# 2. Eliminar ArgoCD Application
#############################################################################

if kubectl get application gitops-platform -n argocd &> /dev/null; then
    log_info "Eliminando ArgoCD Application..."
    kubectl delete application gitops-platform -n argocd
    log_success "ArgoCD Application eliminada"
else
    log_info "ArgoCD Application no existe"
fi

#############################################################################
# 3. Eliminar Namespace gitops-app
#############################################################################

if kubectl get namespace gitops-app &> /dev/null; then
    log_info "Eliminando namespace gitops-app..."
    kubectl delete namespace gitops-app
    log_success "Namespace gitops-app eliminado"
else
    log_info "Namespace gitops-app no existe"
fi

#############################################################################
# 4. Eliminar ArgoCD (Opcional)
#############################################################################

echo ""
read -p "¿Eliminar ArgoCD completamente? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if kubectl get namespace argocd &> /dev/null; then
        log_info "Eliminando ArgoCD..."
        kubectl delete namespace argocd
        log_success "ArgoCD eliminado"
    else
        log_info "ArgoCD no está instalado"
    fi
fi

#############################################################################
# 5. Eliminar Minikube (Opcional)
#############################################################################

echo ""
read -p "¿Eliminar Minikube cluster completamente? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if minikube status &> /dev/null; then
        log_info "Deteniendo Minikube..."
        minikube stop
        log_info "Eliminando Minikube cluster..."
        minikube delete
        log_success "Minikube eliminado"
    else
        log_info "Minikube no está corriendo"
    fi
fi

#############################################################################
# 6. Limpiar Contenedores Docker (Opcional)
#############################################################################

echo ""
read -p "¿Eliminar contenedores Docker de gitops? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log_info "Deteniendo contenedores gitops..."
    docker ps -a | grep gitops | awk '{print $1}' | xargs docker stop 2>/dev/null || true
    docker ps -a | grep gitops | awk '{print $1}' | xargs docker rm 2>/dev/null || true
    log_success "Contenedores eliminados"
    
    read -p "¿Eliminar también las imágenes Docker? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Eliminando imágenes gitops..."
        docker images | grep gitops | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true
        log_success "Imágenes eliminadas"
    fi
fi

#############################################################################
# 7. Limpiar Archivos Temporales
#############################################################################

echo ""
log_info "Limpiando archivos temporales..."

# Eliminar logs
rm -f /tmp/backend.log /tmp/frontend.log /tmp/gitops-pids.txt

# Eliminar Python cache
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Eliminar node_modules (opcional)
read -p "¿Eliminar node_modules del frontend? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "app/frontend/node_modules" ]; then
        rm -rf app/frontend/node_modules
        log_success "node_modules eliminado"
    fi
fi

# Eliminar venv (opcional)
read -p "¿Eliminar virtual environment del backend? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d "app/backend/venv" ]; then
        rm -rf app/backend/venv
        log_success "venv eliminado"
    fi
fi

log_success "Archivos temporales limpiados"

#############################################################################
# Resumen
#############################################################################

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                    CLEANUP COMPLETO                            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

log_success "Cleanup completado exitosamente!"
echo ""

log_info "Para volver a instalar:"
echo "  ./scripts/setup-complete.sh"
echo ""

log_info "Para desarrollo local:"
echo "  ./scripts/dev.sh"
echo ""