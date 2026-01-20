#!/bin/bash

set -e

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${PURPLE}"
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║                                                        ║
║          GitOps Platform - Desarrollo Local           ║
║                                                        ║
╚════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

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

# Verificar que estamos en la raíz del proyecto
if [ ! -d "app/backend" ] || [ ! -d "app/frontend" ]; then
    log_error "Este script debe ejecutarse desde la raíz del proyecto gitops/"
    exit 1
fi

# Verificar .env
if [ ! -f ".env" ]; then
    log_warning "Archivo .env no encontrado, creando desde .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo ""
        log_warning "¡IMPORTANTE! Edita .env y añade tus tokens antes de hacer deployments reales"
        log_info "Por ahora puedes probar la UI, pero el botón Deploy no funcionará sin tokens"
        echo ""
    else
        log_error "Tampoco existe .env.example. Crea uno primero."
        exit 1
    fi
fi

# Función para cleanup al salir
cleanup() {
    echo ""
    log_info "Deteniendo servicios..."
    
    # Matar procesos del backend y frontend
    pkill -f "uvicorn app.main:app" 2>/dev/null || true
    pkill -f "vite" 2>/dev/null || true
    
    # Desactivar virtual environment si está activo
    deactivate 2>/dev/null || true
    
    log_success "Servicios detenidos"
    exit 0
}

# Capturar Ctrl+C
trap cleanup SIGINT SIGTERM

# ============================================
# BACKEND
# ============================================

log_info "Preparando backend..."

cd app/backend

# Crear virtual environment si no existe
if [ ! -d "venv" ]; then
    log_info "Creando virtual environment para Python..."
    python3 -m venv venv
fi

# Activar virtual environment
source venv/bin/activate

# Instalar/actualizar dependencias
log_info "Instalando dependencias del backend..."
pip install -q --upgrade pip
pip install -q -r requirements.txt

# Cargar variables de entorno desde .env
if [ -f "../../.env" ]; then
    set -a
    source ../../.env
    set +a
fi

# Iniciar backend en background
log_info "Iniciando backend en http://localhost:8000..."
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000 > /tmp/backend.log 2>&1 &
BACKEND_PID=$!

cd ../..

# Esperar a que el backend esté listo
log_info "Esperando a que el backend esté listo..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        log_success "Backend funcionando correctamente ✓"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        log_error "Backend no respondió en 30 segundos"
        log_info "Revisa los logs en: tail -f /tmp/backend.log"
        cleanup
    fi
done

# ============================================
# FRONTEND
# ============================================

log_info "Preparando frontend..."

cd app/frontend

# Instalar dependencias si no existen
if [ ! -d "node_modules" ]; then
    log_info "Instalando dependencias del frontend..."
    npm install
fi

# Iniciar frontend en background
log_info "Iniciando frontend en http://localhost:3000..."
npm run dev > /tmp/frontend.log 2>&1 &
FRONTEND_PID=$!

cd ../..

# Esperar a que el frontend esté listo
log_info "Esperando a que el frontend esté listo..."
sleep 3

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ Aplicación corriendo en modo desarrollo${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BLUE}Servicios disponibles:${NC}"
echo -e "  🌐 Frontend:   ${GREEN}http://localhost:3000${NC}"
echo -e "  ⚙️  Backend:    ${GREEN}http://localhost:8000${NC}"
echo -e "  📚 API Docs:   ${GREEN}http://localhost:8000/docs${NC}"
echo ""
echo -e "${BLUE}Logs:${NC}"
echo -e "  Backend:  ${YELLOW}tail -f /tmp/backend.log${NC}"
echo -e "  Frontend: ${YELLOW}tail -f /tmp/frontend.log${NC}"
echo ""
echo -e "${YELLOW}Presiona Ctrl+C para detener todos los servicios${NC}"
echo ""

# Mantener el script corriendo
wait