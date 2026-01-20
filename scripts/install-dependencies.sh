#!/bin/bash

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

echo ""
log_info "Instalando dependencias del proyecto..."
echo ""

# Backend dependencies
log_info "Instalando dependencias del backend..."
cd app/backend

if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip > /dev/null
pip install -r requirements.txt

log_success "Dependencias del backend instaladas"
deactivate
cd ../..

# Frontend dependencies
log_info "Instalando dependencias del frontend..."
cd app/frontend

npm install

log_success "Dependencias del frontend instaladas"
cd ../..

echo ""
log_success "¡Todas las dependencias instaladas correctamente!"
echo ""
echo -e "${BLUE}Comandos disponibles:${NC}"
echo "  ./scripts/dev.sh           - Iniciar en modo desarrollo"
echo "  ./scripts/build-images.sh  - Construir imágenes Docker"
echo "  ./scripts/setup.sh         - Setup completo con Kubernetes"
echo ""