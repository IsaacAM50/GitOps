#!/bin/bash

#############################################################################
# GitOps Platform - Build Docker Images
# 
# Este script construye las imágenes Docker localmente para testing
#
# Uso: ./build-images.sh [username]
#############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

log_step() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Banner
echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║        GitOps Platform - Build Docker Images                  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar que estamos en la raíz del proyecto
if [ ! -d "app/backend" ] || [ ! -d "app/frontend" ]; then
    log_error "Este script debe ejecutarse desde la raíz del proyecto"
    exit 1
fi

# Obtener username
USERNAME=${1:-demo}
log_info "Username: ${USERNAME}"

# Cargar .env si existe
if [ -f ".env" ]; then
    set -a
    source .env
    set +a
    log_info "Variables de entorno cargadas desde .env"
fi

# Generar timestamp para el tag
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TAG="${USERNAME}-${TIMESTAMP}"

log_info "Tag generado: ${TAG}"

# Determinar registry y repo
if [ -n "$GITHUB_USERNAME" ]; then
    REGISTRY="ghcr.io"
    REPO_PREFIX="${GITHUB_USERNAME}"
    if [ -n "$REPO_NAME" ]; then
        REPO="${REPO_NAME}"
    else
        REPO="gitops"
    fi
else
    # Uso local sin registry
    REGISTRY="localhost"
    REPO_PREFIX=""
    REPO="gitops"
fi

log_info "Registry: ${REGISTRY}"
log_info "Repository: ${REPO_PREFIX}/${REPO}"

#############################################################################
# BACKEND
#############################################################################

log_step "Construyendo Backend"

cd app/backend

log_info "Contexto: $(pwd)"
log_info "Dockerfile: $(ls -la Dockerfile)"

# Fix Dockerfile si tiene --platform
if grep -q "FROM --platform" Dockerfile; then
    log_warning "Dockerfile contiene --platform, corrigiendo..."
    sed -i.bak 's/FROM --platform=\$BUILDPLATFORM/FROM/g' Dockerfile
    log_success "Dockerfile corregido"
fi

# Construir imagen
log_info "Ejecutando docker build..."

if [ -n "$GITHUB_USERNAME" ]; then
    # Build para GHCR
    docker build \
        --build-arg USERNAME=${USERNAME} \
        -t ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${TAG} \
        -t ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${USERNAME} \
        -t ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:latest \
        .
else
    # Build local
    docker build \
        --build-arg USERNAME=${USERNAME} \
        -t gitops-backend:${TAG} \
        -t gitops-backend:${USERNAME} \
        -t gitops-backend:latest \
        .
fi

log_success "Backend image construida"

cd ../..

#############################################################################
# FRONTEND
#############################################################################

log_step "Construyendo Frontend"

cd app/frontend

log_info "Contexto: $(pwd)"
log_info "Dockerfile: $(ls -la Dockerfile)"

# Construir imagen
log_info "Ejecutando docker build..."

if [ -n "$GITHUB_USERNAME" ]; then
    # Build para GHCR
    docker build \
        --build-arg USERNAME=${USERNAME} \
        -t ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${TAG} \
        -t ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${USERNAME} \
        -t ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:latest \
        .
else
    # Build local
    docker build \
        --build-arg USERNAME=${USERNAME} \
        -t gitops-frontend:${TAG} \
        -t gitops-frontend:${USERNAME} \
        -t gitops-frontend:latest \
        .
fi

log_success "Frontend image construida"

cd ../..

#############################################################################
# RESUMEN
#############################################################################

log_step "Imágenes Construidas"

echo ""
log_success "Build completado exitosamente!"
echo ""

if [ -n "$GITHUB_USERNAME" ]; then
    echo -e "${GREEN}Imágenes creadas:${NC}"
    echo ""
    echo "Backend:"
    echo "  - ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${TAG}"
    echo "  - ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${USERNAME}"
    echo "  - ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:latest"
    echo ""
    echo "Frontend:"
    echo "  - ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${TAG}"
    echo "  - ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${USERNAME}"
    echo "  - ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:latest"
    echo ""
    
    echo -e "${YELLOW}Para hacer push a GHCR:${NC}"
    echo ""
    echo "# Login"
    echo "echo \$GITHUB_TOKEN | docker login ghcr.io -u ${GITHUB_USERNAME} --password-stdin"
    echo ""
    echo "# Push backend"
    echo "docker push ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${TAG}"
    echo "docker push ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${USERNAME}"
    echo "docker push ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:latest"
    echo ""
    echo "# Push frontend"
    echo "docker push ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${TAG}"
    echo "docker push ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${USERNAME}"
    echo "docker push ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:latest"
    echo ""
else
    echo -e "${GREEN}Imágenes creadas (local):${NC}"
    echo ""
    echo "Backend:"
    echo "  - gitops-backend:${TAG}"
    echo "  - gitops-backend:${USERNAME}"
    echo "  - gitops-backend:latest"
    echo ""
    echo "Frontend:"
    echo "  - gitops-frontend:${TAG}"
    echo "  - gitops-frontend:${USERNAME}"
    echo "  - gitops-frontend:latest"
    echo ""
fi

echo -e "${YELLOW}Para probar localmente:${NC}"
echo ""
echo "# Backend"
echo "docker run -d -p 8000:8000 \\"
if [ -n "$GITHUB_USERNAME" ]; then
    echo "  ${REGISTRY}/${REPO_PREFIX}/${REPO}-backend:${USERNAME}"
else
    echo "  gitops-backend:${USERNAME}"
fi
echo ""
echo "# Frontend"
echo "docker run -d -p 3000:3000 \\"
if [ -n "$GITHUB_USERNAME" ]; then
    echo "  ${REGISTRY}/${REPO_PREFIX}/${REPO}-frontend:${USERNAME}"
else
    echo "  gitops-frontend:${USERNAME}"
fi
echo ""

echo -e "${YELLOW}Ver imágenes:${NC}"
echo "docker images | grep gitops"
echo ""