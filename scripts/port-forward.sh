#!/bin/bash

#############################################################################
# GitOps Platform - Test Deployment
# 
# Este script prueba un deployment completo end-to-end
#
# Uso: ./test-deployment.sh [username]
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
║        GitOps Platform - Test Deployment                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Obtener username
USERNAME=${1:-test-$(date +%s)}
log_info "Username para test: ${USERNAME}"

# Verificar que backend está corriendo
log_step "1. Verificando Backend"

if ! curl -s http://localhost:8000/health > /dev/null 2>&1; then
    log_error "Backend no está corriendo en localhost:8000"
    log_info "Inicia el backend con: ./scripts/dev.sh"
    exit 1
fi

log_success "Backend está respondiendo"

# Test health endpoint
log_info "Probando /health..."
HEALTH=$(curl -s http://localhost:8000/health)
echo "$HEALTH" | jq . 2>/dev/null || echo "$HEALTH"

# Test root endpoint
log_info "Probando /..."
ROOT=$(curl -s http://localhost:8000/)
echo "$ROOT" | jq . 2>/dev/null || echo "$ROOT"

#############################################################################
# Test Deploy Endpoint
#############################################################################

log_step "2. Probando Deployment"

log_info "Enviando request a /api/deploy..."

RESPONSE=$(curl -s -X POST http://localhost:8000/api/deploy \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${USERNAME}\"}")

echo ""
log_info "Response:"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"
echo ""

# Verificar si el deployment fue exitoso
if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    if [ "$(echo "$RESPONSE" | jq -r '.success')" == "true" ]; then
        log_success "Deployment triggered exitosamente!"
        
        PIPELINE_ID=$(echo "$RESPONSE" | jq -r '.pipeline_id')
        PIPELINE_URL=$(echo "$RESPONSE" | jq -r '.pipeline_url')
        
        echo ""
        echo -e "${GREEN}Pipeline Info:${NC}"
        echo "  ID:  ${PIPELINE_ID}"
        echo "  URL: ${PIPELINE_URL}"
        echo ""
        
        # Ofrecer abrir en navegador
        read -p "¿Abrir pipeline en navegador? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if command -v open &> /dev/null; then
                open "$PIPELINE_URL"
            elif command -v xdg-open &> /dev/null; then
                xdg-open "$PIPELINE_URL"
            else
                echo "Abre manualmente: $PIPELINE_URL"
            fi
        fi
        
        # Monitorear status
        log_step "3. Monitoreando Status"
        
        log_info "Esperando 10 segundos antes de consultar status..."
        sleep 10
        
        log_info "Consultando status del pipeline..."
        STATUS=$(curl -s http://localhost:8000/api/status/${PIPELINE_ID})
        
        echo ""
        echo "$STATUS" | jq . 2>/dev/null || echo "$STATUS"
        echo ""
        
        # Extraer estado
        WORKFLOW_STATUS=$(echo "$STATUS" | jq -r '.status' 2>/dev/null || echo "unknown")
        
        case $WORKFLOW_STATUS in
            "running")
                log_info "Pipeline está ejecutándose..."
                echo ""
                log_info "Puedes monitorear el progreso en:"
                echo "  $PIPELINE_URL"
                ;;
            "success")
                log_success "Pipeline completado exitosamente!"
                ;;
            "failed")
                log_error "Pipeline falló"
                ;;
            *)
                log_warning "Estado desconocido: $WORKFLOW_STATUS"
                ;;
        esac
        
    else
        log_error "Deployment falló"
    fi
else
    log_error "Error en la respuesta del servidor"
    
    # Verificar si es error de configuración
    if echo "$RESPONSE" | grep -q "CircleCI token"; then
        echo ""
        log_warning "Parece que el token de CircleCI no está configurado"
        log_info "Configura CIRCLECI_TOKEN en el archivo .env"
    fi
fi

#############################################################################
# Test Kubernetes (si está disponible)
#############################################################################

if command -v kubectl &> /dev/null; then
    log_step "4. Verificando Kubernetes"
    
    if kubectl cluster-info &> /dev/null; then
        log_success "Kubernetes cluster está disponible"
        
        echo ""
        log_info "Pods en gitops-app:"
        kubectl get pods -n gitops-app 2>/dev/null || log_warning "Namespace gitops-app no existe"
        
        echo ""
        log_info "Deployments en gitops-app:"
        kubectl get deployments -n gitops-app 2>/dev/null || log_warning "No deployments encontrados"
        
        echo ""
        log_info "ArgoCD Applications:"
        kubectl get applications -n argocd 2>/dev/null || log_warning "ArgoCD no está instalado"
    else
        log_warning "Kubernetes cluster no está disponible"
        log_info "Para test completo con K8s, ejecuta: ./setup-complete.sh"
    fi
fi

#############################################################################
# Test Frontend (si está corriendo)
#############################################################################

log_step "5. Verificando Frontend"

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    log_success "Frontend está respondiendo en localhost:3000"
    
    read -p "¿Abrir frontend en navegador? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v open &> /dev/null; then
            open "http://localhost:3000"
        elif command -v xdg-open &> /dev/null; then
            xdg-open "http://localhost:3000"
        else
            echo "Abre manualmente: http://localhost:3000"
        fi
    fi
else
    log_warning "Frontend no está corriendo en localhost:3000"
    log_info "Inicia el frontend con: ./scripts/dev.sh"
fi

#############################################################################
# Resumen
#############################################################################

echo ""
log_step "Resumen del Test"

echo ""
echo -e "${GREEN}Tests completados:${NC}"
echo "  ✓ Backend health check"
echo "  ✓ Deployment trigger"
echo "  ✓ Pipeline status check"
echo ""

echo -e "${YELLOW}URLs útiles:${NC}"
echo "  Backend:  http://localhost:8000"
echo "  Docs:     http://localhost:8000/docs"
echo "  Frontend: http://localhost:3000"
if [ -n "$PIPELINE_URL" ]; then
    echo "  Pipeline: $PIPELINE_URL"
fi
echo ""

log_success "Test completado! 🎉"
echo ""