#!/bin/bash

# Construir Backend
echo "Construyendo backend..."
cd app/backend
docker build -t gitops-backend:test --build-arg USERNAME=isaac .

# Ejecutar Backend
echo "Ejecutando backend..."
docker run -d -p 8000:8000 \
  -e CIRCLECI_TOKEN=TU TOKEN DE CIRCLE CI \
  -e GITHUB_USERNAME=IsaacAM50 \
  -e REPO_NAME=GitOps \
  --name gitops-backend \
  gitops-backend:test

# Esperar que el backend esté listo
sleep 5

# Probar Backend
echo "Probando backend..."
curl http://localhost:8000/health

# Construir Frontend
echo "Construyendo frontend..."
cd ../frontend
docker build -t gitops-frontend:test --build-arg USERNAME=IsaacAM50 .

# Ejecutar Frontend
echo "Ejecutando frontend..."
docker run -d -p 3000:3000 --name gitops-frontend gitops-frontend:test

# Esperar que el frontend esté listo
sleep 3

# Abrir en navegador
echo "Abriendo navegador..."
open http://localhost:3000

# Mostrar logs
echo "Contenedores ejecutándose:"
docker ps --filter "name=gitops"

echo "Para ver logs del backend: docker logs -f gitops-backend"
echo "Para ver logs del frontend: docker logs -f gitops-frontend"
echo "Para detener: docker stop gitops-backend gitops-frontend"