import asyncio
import logging
import os
import subprocess
from datetime import datetime
from enum import Enum
from typing import Dict, List

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class CircuitState(str, Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"


class ServiceInstance(BaseModel):
    name: str
    host: str
    port: int


class ServiceStatus(BaseModel):
    name: str
    host: str
    port: int
    state: CircuitState
    consecutive_failures: int
    last_check: datetime | None = None
    last_failure: datetime | None = None


registry: Dict[str, ServiceStatus] = {}

HEALTH_CHECK_INTERVAL = int(os.getenv("HEALTH_CHECK_INTERVAL", "10"))
HEALTH_CHECK_TIMEOUT = int(os.getenv("HEALTH_CHECK_TIMEOUT", "5"))
MAX_FAILURES = int(os.getenv("MAX_FAILURES", "3"))
COOLDOWN_SECONDS = int(os.getenv("COOLDOWN_SECONDS", "30"))
UPSTREAMS_FILE = os.getenv("UPSTREAMS_FILE", "/etc/nginx/conf.d/upstreams.conf")
RELOAD_NGINX_ENABLED = os.getenv("RELOAD_NGINX_ENABLED", "true").lower() == "true"

app = FastAPI(title="Service Discovery", version="1.0.0")

DOCKER_ENABLED = False
logger.info("Manual registration mode enabled")


@app.on_event("startup")
async def startup_event():
    asyncio.create_task(health_check_loop())
    logger.info(f"Discovery started. Health check every {HEALTH_CHECK_INTERVAL}s")


@app.post("/register")
def register_service(instance: ServiceInstance):
    key = f"{instance.name}:{instance.host}:{instance.port}"
    
    if key in registry:
        logger.info(f"Already registered: {key}")
        return {"message": "already registered", "key": key}
    
    registry[key] = ServiceStatus(
        name=instance.name,
        host=instance.host,
        port=instance.port,
        state=CircuitState.CLOSED,
        consecutive_failures=0,
        last_check=None,
        last_failure=None,
    )
    
    logger.info(f"Registered: {key}")
    update_upstreams()
    
    return {"message": "registered", "key": key}


@app.delete("/register")
def unregister_service(instance: ServiceInstance):
    key = f"{instance.name}:{instance.host}:{instance.port}"
    
    if key not in registry:
        raise HTTPException(status_code=404, detail="service not found")
    
    del registry[key]
    logger.info(f"Unregistered: {key}")
    update_upstreams()
    
    return {"message": "unregistered", "key": key}


@app.get("/registry")
def get_registry():
    return {
        "services": [
            {
                "key": key,
                "name": status.name,
                "host": status.host,
                "port": status.port,
                "state": status.state,
                "consecutive_failures": status.consecutive_failures,
                "last_check": status.last_check.isoformat() if status.last_check else None,
                "last_failure": status.last_failure.isoformat() if status.last_failure else None,
            }
            for key, status in registry.items()
        ]
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "registered_services": len(registry),
        "healthy_services": sum(1 for s in registry.values() if s.state == CircuitState.CLOSED),
    }


async def health_check_loop():
    await asyncio.sleep(5)
    
    while True:
        try:
            await perform_health_checks()
        except Exception as e:
            logger.error(f"Health check error: {e}")
        
        await asyncio.sleep(HEALTH_CHECK_INTERVAL)


async def perform_health_checks():
    if not registry:
        return
    
    async with httpx.AsyncClient(timeout=HEALTH_CHECK_TIMEOUT) as client:
        for key, status in registry.items():
            await check_service_health(client, key, status)
    
    update_upstreams()


async def check_service_health(client: httpx.AsyncClient, key: str, status: ServiceStatus):
    url = f"http://{status.host}:{status.port}/health"
    now = datetime.utcnow()
    
    try:
        if status.state == CircuitState.OPEN:
            if status.last_failure:
                elapsed = (now - status.last_failure).total_seconds()
                if elapsed >= COOLDOWN_SECONDS:
                    logger.info(f"{key}: OPEN -> HALF_OPEN")
                    status.state = CircuitState.HALF_OPEN
                else:
                    return
        
        response = await client.get(url)
        status.last_check = now
        
        if response.status_code == 200:
            if status.state == CircuitState.HALF_OPEN:
                logger.info(f"{key}: HALF_OPEN -> CLOSED")
                status.state = CircuitState.CLOSED
                status.consecutive_failures = 0
            elif status.consecutive_failures > 0:
                logger.info(f"{key} recovered")
                status.consecutive_failures = 0
        else:
            handle_health_check_failure(key, status, now)
    
    except (httpx.RequestError, httpx.TimeoutException) as e:
        logger.warning(f"{key} unreachable: {e}")
        handle_health_check_failure(key, status, now)


def handle_health_check_failure(key: str, status: ServiceStatus, now: datetime):
    status.consecutive_failures += 1
    status.last_failure = now
    status.last_check = now
    
    logger.warning(f"{key} failed ({status.consecutive_failures}/{MAX_FAILURES})")
    
    if status.state == CircuitState.HALF_OPEN:
        logger.error(f"{key}: HALF_OPEN -> OPEN")
        status.state = CircuitState.OPEN
    elif status.consecutive_failures >= MAX_FAILURES and status.state == CircuitState.CLOSED:
        logger.error(f"{key}: CLOSED -> OPEN")
        status.state = CircuitState.OPEN


def update_upstreams():
    try:
        healthy_services = [
            status for status in registry.values()
            if status.state == CircuitState.CLOSED
        ]
        
        if not healthy_services:
            logger.warning("No healthy services")
            return
        
        content = generate_upstreams_config(healthy_services)
        
        with open(UPSTREAMS_FILE, "w") as f:
            f.write(content)
        
        logger.info(f"Updated upstream: {len(healthy_services)} services")
        
        if RELOAD_NGINX_ENABLED:
            reload_nginx()
    
    except Exception as e:
        logger.error(f"Update upstream failed: {e}")


def generate_upstreams_config(services: List[ServiceStatus]) -> str:
    lines = [
        "upstream backend {",
        "    least_conn;",
        "",
    ]
    
    for service in services:
        lines.append(
            f"    server {service.host}:{service.port} "
            f"max_fails={MAX_FAILURES} fail_timeout={COOLDOWN_SECONDS}s;"
        )
    
    lines.append("}")
    
    return "\n".join(lines)


def reload_nginx():
    try:
        result = subprocess.run(
            ["docker", "exec", "gateway", "nginx", "-s", "reload"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        
        if result.returncode == 0:
            logger.info("Nginx reloaded")
        else:
            logger.error(f"Reload failed: {result.stderr}")
    
    except FileNotFoundError:
        try:
            result = subprocess.run(
                ["nginx", "-s", "reload"],
                capture_output=True,
                text=True,
                timeout=5,
            )
            
            if result.returncode == 0:
                logger.info("Nginx reloaded")
            else:
                logger.error(f"Reload failed: {result.stderr}")
        
        except Exception as e:
            logger.error(f"Reload error: {e}")
    
    except Exception as e:
        logger.error(f"Reload error: {e}")
