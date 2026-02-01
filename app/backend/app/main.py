from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.metrics import MetricsMiddleware, track_deployment, get_metrics
from pydantic import BaseModel
import httpx
import os
from typing import Optional
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="GitOps Platform API",
    description="API para deployments personalizados con GitOps",
    version="1.0.0"
)

app = MetricsMiddleware(app) 
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

class DeployRequest(BaseModel):
    username: str

class DeployResponse(BaseModel):
    success: bool
    message: str
    pipeline_id: Optional[str] = None
    pipeline_url: Optional[str] = None

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
                        "running": "🔄 Pipeline ejecutándose...",
                        "success": "✅ Deployment completado exitosamente!",
                        "failed": "❌ Deployment falló. Revisa los logs en CircleCI.",
                        "canceled": "⚠️ Deployment cancelado",
                        "on_hold": "⏸️ Pipeline en espera de aprobación"
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
        content=get_metrics(),
        media_type="text/plain"
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)