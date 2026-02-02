from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from starlette.middleware.base import BaseHTTPMiddleware
from pydantic import BaseModel
from prometheus_client import Counter, Gauge, generate_latest
from functools import wraps
import httpx
import os
from typing import Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


# MÉTRICAS PARA PROMETHEUS

requests_total = Counter('requests_total', 'Total de requests', ['status'])
deployments_success = Counter('deployments_success_total', 'Deployments exitosos')
deployments_failed = Counter('deployments_failed_total', 'Deployments fallidos')
deployments_active = Gauge('deployments_active', 'Deployments ejecutándose ahora')


# MIDDLEWARE

class MetricsMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        try:
            response = await call_next(request)
            status = "2xx" if response.status_code < 300 else "error"
            requests_total.labels(status=status).inc()
            return response
        except Exception:
            requests_total.labels(status="error").inc()
            raise


# DECORATOR PARA DEPLOYMENTS

def track_deployment():
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            deployments_active.inc()
            try:
                result = await func(*args, **kwargs)
                deployments_success.inc()
                return result
            except Exception:
                deployments_failed.inc()
                raise
            finally:
                deployments_active.dec()
        return wrapper
    return decorator


# APP

app = FastAPI(
    title="GitOps Platform API",
    description="API para deployments personalizados con GitOps",
    version="1.0.0"
)

app.add_middleware(MetricsMiddleware)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

CIRCLECI_TOKEN = os.getenv("CIRCLECI_TOKEN")
GITHUB_USERNAME = os.getenv("GITHUB_USERNAME")
REPO_NAME = os.getenv("REPO_NAME", "gitops")
CIRCLECI_API_URL = "https://circleci.com/api/v2"


# MODELS

class DeployRequest(BaseModel):
    username: str

class DeployResponse(BaseModel):
    success: bool
    message: str
    pipeline_id: Optional[str] = None
    pipeline_url: Optional[str] = None


# ENDPOINTS

@app.get("/")
async def root():
    """Endpoint raíz con información de la API"""
    return {
        "message": "GitOps Platform API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "deploy": "/api/deploy",
            "status": "/api/status/{pipeline_id}",
            "metrics": "/metrics",
            "docs": "/docs"
        }
    }

@app.get("/health")
async def health():
    """Health check endpoint para Kubernetes probes"""
    return {
        "status": "healthy",
        "service": "backend",
        "circleci_configured": CIRCLECI_TOKEN is not None
    }

@app.post("/api/deploy", response_model=DeployResponse)
@track_deployment()
async def trigger_deployment(request: DeployRequest):
    """
    Triggerea un pipeline de CircleCI con el username personalizado

    Args:
        request: Objeto con el username del usuario

    Returns:
        DeployResponse con información del pipeline creado
    """
    if not CIRCLECI_TOKEN:
        raise HTTPException(
            status_code=500,
            detail="CircleCI token no configurado. Añade CIRCLECI_TOKEN al .env"
        )

    if not request.username or len(request.username) < 2:
        raise HTTPException(
            status_code=400,
            detail="Username debe tener al menos 2 caracteres"
        )

    # Sanitizar username (solo alfanuméricos y guiones)
    username = "".join(c for c in request.username if c.isalnum() or c == "-").lower()

    if not username:
        raise HTTPException(
            status_code=400,
            detail="Username inválido. Usa solo letras, números y guiones"
        )

    logger.info(f"🚀 Triggering deployment for user: {username}")

    try:
        # Trigger CircleCI pipeline con parámetros
        url = f"{CIRCLECI_API_URL}/project/github/{GITHUB_USERNAME}/{REPO_NAME}/pipeline"

        payload = {
            "parameters": {
                "username": username,
                "trigger-deploy": True
            },
            "branch": "main"
        }

        headers = {
            "Circle-Token": CIRCLECI_TOKEN,
            "Content-Type": "application/json"
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(url, json=payload, headers=headers)

            if response.status_code == 201:
                data = response.json()
                pipeline_id = data.get("id")
                pipeline_number = data.get("number")

                pipeline_url = f"https://app.circleci.com/pipelines/github/{GITHUB_USERNAME}/{REPO_NAME}/{pipeline_number}"

                logger.info(f"✅ Pipeline triggered successfully: {pipeline_id}")

                return DeployResponse(
                    success=True,
                    message=f"🎉 Deployment iniciado para {username}! Tu versión personalizada se está construyendo...",
                    pipeline_id=pipeline_id,
                    pipeline_url=pipeline_url
                )
            else:
                logger.error(f"❌ CircleCI error: {response.status_code} - {response.text}")
                raise HTTPException(
                    status_code=response.status_code,
                    detail=f"Error al triggerar CircleCI: {response.text}"
                )

    except httpx.TimeoutException:
        logger.error("⏱️ Timeout al conectar con CircleCI")
        raise HTTPException(
            status_code=504,
            detail="Timeout al conectar con CircleCI. Intenta de nuevo."
        )
    except httpx.RequestError as e:
        logger.error(f"🔌 Request error: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Error de conexión con CircleCI: {str(e)}"
        )

@app.get("/api/status/{pipeline_id}")
async def get_pipeline_status(pipeline_id: str):
    """
    Obtiene el status de un pipeline de CircleCI

    Args:
        pipeline_id: ID del pipeline de CircleCI

    Returns:
        Información del estado del pipeline
    """
    if not CIRCLECI_TOKEN:
        raise HTTPException(status_code=500, detail="CircleCI token no configurado")

    try:
        url = f"{CIRCLECI_API_URL}/pipeline/{pipeline_id}/workflow"
        headers = {"Circle-Token": CIRCLECI_TOKEN}

        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.get(url, headers=headers)

            if response.status_code == 200:
                data = response.json()
                workflows = data.get("items", [])

                if workflows:
                    workflow = workflows[0]
                    status = workflow.get("status")

                    # Traducir estados de CircleCI
                    status_messages = {
                        "running": " Pipeline ha empezado...",
                        "success": " Deployment completado exitosamente!",
                        "failed": " Deployment falló. Revisa los logs en CircleCI.",
                        "canceled": " Deployment cancelado",
                        "on_hold": "⏸ Pipeline en espera de aprobación"
                    }

                    return {
                        "pipeline_id": pipeline_id,
                        "status": status,
                        "message": status_messages.get(status, f"Estado: {status}"),
                        "created_at": workflow.get("created_at"),
                        "stopped_at": workflow.get("stopped_at")
                    }
                else:
                    return {
                        "pipeline_id": pipeline_id,
                        "status": "pending",
                        "message": "⏳ Workflow aún no iniciado"
                    }
            else:
                raise HTTPException(
                    status_code=response.status_code,
                    detail="Error al obtener status del pipeline"
                )

    except httpx.RequestError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error de conexión: {str(e)}"
        )

@app.get("/metrics")
async def metrics():
    """Endpoint para Prometheus"""
    return Response(
        content=generate_latest(),
        media_type="text/plain"
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)