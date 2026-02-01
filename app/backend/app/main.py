from prometheus_client import Counter, Histogram, Gauge, generate_latest
from fastapi import Request
from functools import wraps
import time
import logging

logger = logging.getLogger(__name__)


# MÉTRICAS ESENCIALES


# 1. Salud de la API
api_health = Gauge('api_health', 'Estado de salud de la API (1=healthy, 0=unhealthy)')

# 2. Requests totales
requests_total = Counter(
    'api_requests_total',
    'Total de requests a la API',
    ['method', 'endpoint', 'status']
)

# 3. Latencia de requests
request_duration = Histogram(
    'api_request_duration_seconds',
    'Duración de las requests',
    ['endpoint'],
    buckets=[0.1, 0.5, 1.0, 2.0, 5.0]
)

# 4. Deployments
deployments_total = Counter(
    'deployments_total',
    'Total de deployments realizados',
    ['status']  # success, error
)

# 5. Deployments en curso
deployments_in_progress = Gauge(
    'deployments_in_progress',
    'Deployments que se están ejecutando ahora mismo'
)

# 6. Conexión con CircleCI
circleci_connected = Gauge(
    'circleci_connected',
    'Conexión con CircleCI (1=conectado, 0=desconectado)'
)

# MIDDLEWARE SIMPLE

class MetricsMiddleware:
    """Middleware para capturar métricas de requests"""

    def __init__(self, app):
        self.app = app
        # Inicializar salud de API como saludable
        api_health.set(1)

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            return await self.app(scope, receive, send)

        request = Request(scope)
        start_time = time.time()

        # Variables para capturar métricas
        status = "500"
        method = request.method
        path = request.url.path

        async def send_wrapper(message):
            nonlocal status
            if message["type"] == "http.response.start":
                status = str(message["status"])
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)

            # Registrar éxito
            if status.startswith('2'):
                api_health.set(1)
            else:
                api_health.set(0.5)  # Warning

        except Exception:
            api_health.set(0)  # Error
            status = "500"
            raise
        finally:
            # Calcular duración
            duration = time.time() - start_time

            # Registrar métricas
            requests_total.labels(
                method=method,
                endpoint=path,
                status=status
            ).inc()

            request_duration.labels(
                endpoint=path
            ).observe(duration)

            # Log simple para debugging
            logger.debug(f"Métrica: {method} {path} -> {status} ({duration:.2f}s)")

# HELPERS PARA ENDPOINTS

def track_deployment():
    """Helper para trackear deployments"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            deployments_in_progress.inc()
            try:
                result = await func(*args, **kwargs)
                deployments_total.labels(status="success").inc()
                return result
            except Exception:
                deployments_total.labels(status="error").inc()
                raise
            finally:
                deployments_in_progress.dec()
        return wrapper
    return decorator

def track_circleci_call():
    """Helper para trackear llamadas a CircleCI"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            try:
                result = await func(*args, **kwargs)
                circleci_connected.set(1)
                return result
            except Exception:
                circleci_connected.set(0)
                raise
        return wrapper
    return decorator


# ENDPOINT PARA PROMETHEUS

def get_metrics():
    """Devuelve métricas en formato Prometheus"""
    return generate_latest()