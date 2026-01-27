# 🚀 GitOps Platform

<div align="center">

![GitOps](https://img.shields.io/badge/GitOps-Enabled-blue?style=for-the-badge)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white)
![CircleCI](https://img.shields.io/badge/CircleCI-343434?style=for-the-badge&logo=circleci&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)

**Plataforma de deployment automatizado con GitOps para demostración de habilidades DevOps**

[Demo](#-demo) •
[Características](#-características) •
[Arquitectura](#-arquitectura) •
[Instalación](#-instalación-rápida) •
[Documentación](#-documentación)

</div>

---

##  Descripción

GitOps Platform es un proyecto completo de **CI/CD y GitOps** que permite a los usuarios desplegar versiones personalizadas de una aplicación web con un solo click. El proyecto demuestra la implementación de un pipeline moderno de DevOps utilizando buenas prácticas.

### ¿Por Qué Este Proyecto?

Este proyecto fue diseñado específicamente para demostrar competencias en:

-  **Infrastructure as Code (IaC)**: Kubernetes manifests versionados en Git
-  **GitOps Workflow**: ArgoCD sincronización automática desde Git
-  **CI/CD Pipelines**: CircleCI con jobs paralelos y workflows condicionales
-  **Containerización**: Docker multi-stage builds optimizados
-  **Kubernetes**: Deployments, Services, Secrets, ConfigMaps
-  **API Development**: FastAPI con OpenAPI/Swagger
-  **Frontend Moderno**: React + Vite + TailwindCSS
-  **Scripting & Automation**: Bash scripts robustos con manejo de errores

##  Características

### Para Usuarios

-  **Un Click Deploy**: Ingresa tu nombre y despliega tu versión personalizada
-  **Monitoreo en Tiempo Real**: Ve el progreso del deployment en CircleCI
-  **Rollback Automático**: Si algo falla, ArgoCD revierte los cambios
-  **UI Moderna**: Interfaz responsive con animaciones

### Para DevOps Engineers

-  **Secrets Management**: Kubernetes Secrets + CircleCI Contexts
-  **Container Registry**: GitHub Container Registry (GHCR)
-  **Observability**: Health checks, logs, eventos de Kubernetes
-  **Developer Tools**: Scripts de desarrollo, testing, build
-  **Documentación Completa**: Arquitectura, diagramas, guías

##  Arquitectura

### Diagrama de Alto Nivel

```
Usuario → Frontend → Backend → CircleCI → GHCR
                                    ↓
                            Update Manifests
                                    ↓
                             Git Repository
                                    ↓
                                 ArgoCD
                                    ↓
                               Kubernetes
```

### Stack Tecnológico

| Capa | Tecnologías |
|------|-------------|
| **Frontend** | React 18, Vite, TailwindCSS, Lucide Icons |
| **Backend** | FastAPI, Python 3.11, Uvicorn, httpx |
| **CI/CD** | CircleCI, GitHub Actions, Docker |
| **GitOps** | ArgoCD, Kustomize, Git |
| **Infrastructure** | Kubernetes, Minikube, GHCR |
| **Observability** | kubectl, ArgoCD UI, Health Checks |

### Flujo de Deployment

1. **Usuario** ingresa nombre en el frontend
2. **Backend** valida y triggerea pipeline de CircleCI
3. **CircleCI** ejecuta tests, build y push de imágenes Docker
4. **CircleCI** actualiza manifests de Kubernetes en Git
5. **ArgoCD** detecta cambios y sincroniza con el cluster
6. **Kubernetes** despliega la nueva versión con rolling update

Ver [DIAGRAMS.md](DIAGRAMS.md) para diagramas detallados en Mermaid.

## 🚀 Instalación Rápida

### Prerrequisitos

```bash
# Verificar instalaciones
docker --version        # Docker 20.10+
kubectl version        # kubectl 1.28+
minikube version       # Minikube 1.32+
node --version         # Node 18+
python3 --version      # Python 3.11+
```

### Setup Automático (Recomendado)

```bash
# 1. Clonar repositorio
git clone https://github.com/tu-usuario/mlops-personalized-gitops.git
cd mlops-personalized-gitops

# 2. Configurar variables de entorno
cp .env.example .env
nano .env  # Editar con tus tokens

# 3. Ejecutar setup completo
chmod +x scripts/setup-complete.sh
./scripts/setup-complete.sh
```

El script automáticamente:
-  Verifica prerrequisitos
-  Inicia Minikube
-  Instala ArgoCD
-  Crea secrets de Kubernetes
-  Configura ArgoCD Application
-  Inicia port-forwarding

### Setup Manual

Ver [DOCUMENTATION.md](DOCUMENTATION.md) para instrucciones detalladas paso a paso.

## 🎮 Demo

### Desarrollo Local (Sin Kubernetes)

```bash
# Iniciar backend + frontend
./scripts/dev.sh

# Acceder a:
# - Frontend: http://localhost:3000
# - Backend:  http://localhost:8000
# - API Docs: http://localhost:8000/docs
```

### Deployment Completo

```bash
# 1. Setup completo (incluye Kubernetes)
./scripts/setup-complete.sh

# 2. Acceder a servicios:
# - Frontend:  http://localhost:3000
# - Backend:   http://localhost:8000
# - ArgoCD:    https://localhost:8080

# 3. Test de deployment
./scripts/test-deployment.sh my-username
```

## 📁 Estructura del Proyecto

```
mlops-personalized-gitops/
├── .circleci/
│   └── config.yml              # Pipeline de CircleCI
├── app/
│   ├── backend/                # API FastAPI
│   │   ├── app/
│   │   │   └── main.py
│   │   ├── tests/
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── frontend/               # React App
│       ├── src/
│       │   ├── App.jsx
│       │   └── main.jsx
│       ├── Dockerfile
│       └── package.json
├── kubernetes/                 # Kubernetes Manifests
│   ├── backend-deployment.yaml
│   ├── backend-service.yaml
│   ├── frontend-deployment.yaml
│   ├── frontend-service.yaml
│   ├── backend-secrets.yaml
│   └── frontend-configmap.yaml
├── scripts/                    # Automation Scripts
│   ├── setup-complete.sh       # Setup automático completo
│   ├── dev.sh                  # Desarrollo local
│   ├── build-images.sh         # Build Docker images
│   ├── test-deployment.sh      # Test end-to-end
│   └── install-dependencies.sh # Instalar dependencias
├── .env.example               # Template de variables
├── DOCUMENTATION.md           # Documentación completa
├── DIAGRAMS.md               # Diagramas Mermaid
└── README.md                 # Este archivo
```

##  Documentación

| Documento | Descripción |
|-----------|-------------|
| [DOCUMENTATION.md](DOCUMENTATION.md) | Documentación técnica completa con guías paso a paso |
| [DIAGRAMS.md](DIAGRAMS.md) | Diagramas de arquitectura en formato Mermaid |
| [INTERVIEW_GUIDE.md](INTERVIEW_GUIDE.md) | Guía para explicar el proyecto en entrevistas |

### Scripts Disponibles

| Script | Propósito |
|--------|-----------|
| `setup-complete.sh` | Setup completo automatizado (Minikube + ArgoCD + App) |
| `dev.sh` | Desarrollo local (Backend + Frontend sin K8s) |
| `build-images.sh` | Build de imágenes Docker localmente |
| `test-deployment.sh` | Test end-to-end del deployment |
| `install-dependencies.sh` | Instalar todas las dependencias |

## 🔧 Configuración

### Variables de Entorno Requeridas

```bash
# .env
CIRCLECI_TOKEN=your_circleci_token
GITHUB_USERNAME=your-github-username
GITHUB_TOKEN=your_github_token
REPO_NAME=mlops-personalized-gitops
GITOPS_REPO_NAME=GitOps-Manifests
```

### Generar Tokens

**CircleCI Token:**
1. https://app.circleci.com/settings/user/tokens
2. Create New Token
3. Nombre: "GitOps Platform"

**GitHub Token:**
1. https://github.com/settings/tokens
2. Generate new token (classic)
3. Scopes: `repo`, `write:packages`, `read:packages`

### CircleCI Context

Crear context "github-packages" con:
- `GITHUB_USERNAME`
- `GITHUB_TOKEN`
- `GITOPS_REPO_NAME`

## 🐛 Troubleshooting

### Backend no conecta con CircleCI

```bash
# Verificar token
cat .env | grep CIRCLECI_TOKEN

# Test manual
curl -H "Circle-Token: $CIRCLECI_TOKEN" \
  https://circleci.com/api/v2/me
```

### ArgoCD no sincroniza

```bash
# Ver estado de la application
kubectl get application gitops-platform -n argocd

# Forzar sync
kubectl patch application gitops-platform -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'

# Ver logs de ArgoCD
kubectl logs -n argocd deployment/argocd-repo-server
```

### Pod en ImagePullBackOff

```bash
# Verificar que imagen existe en GHCR
docker pull ghcr.io/user/repo-backend:tag

# Verificar que package es público
# GitHub → Package settings → Change visibility

# O crear imagePullSecret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USERNAME \
  --docker-password=$GITHUB_TOKEN \
  -n gitops-app
```

Ver [DOCUMENTATION.md#troubleshooting](DOCUMENTATION.md#9-troubleshooting) para más soluciones.

##  Comandos Útiles

```bash
# Ver estado del cluster
kubectl get all -n gitops-app

# Logs del backend
kubectl logs -f deployment/gitops-backend -n gitops-app

# Logs del frontend
kubectl logs -f deployment/gitops-frontend -n gitops-app

# Estado de ArgoCD
kubectl get applications -n argocd

# Describir pod (eventos)
kubectl describe pod POD_NAME -n gitops-app

# Port-forward manual
kubectl port-forward svc/gitops-backend-service -n gitops-app 8000:8000
```


Este proyecto demuestra:

### Competencias Técnicas

-  **Kubernetes**: Deployments, Services, ConfigMaps, Secrets
-  **GitOps**: ArgoCD con auto-sync y self-heal
-  **CI/CD**: CircleCI con workflows y jobs paralelos
-  **Docker**: Multi-stage builds, optimización de imágenes
-  **Backend Development**: FastAPI, Python, REST APIs
-  **Frontend Development**: React, Modern JavaScript
-  **Infrastructure as Code**: YAML manifests versionados
-  **Scripting**: Bash con manejo de errores robusto
-  **Observability**: Logs, health checks, monitoring

### Mejores Prácticas

-  Git como fuente única de verdad
-  Secrets management con Kubernetes Secrets
-  Automated testing en CI/CD
-  Rolling updates con health checks
-  Documentación exhaustiva
-  Scripts de automatización reutilizables
-  Separación de concerns (config vs código)

##  Contribución

Este es un proyecto de portfolio personal. Si encuentras bugs o tienes sugerencias contactame por mi LinkedIn

<div align="center">

** Si este proyecto te resultó útil, considera darle una estrella!**

Hecho con ❤️ por Isaac Adams como proyecto de portfolio DevOps

</div>