import asyncio
import logging
import os
import tempfile
import time
from contextlib import asynccontextmanager

import httpx
from fastapi import FastAPI, Request
from pydantic import BaseModel


# =====================================================================
# Logging
# =====================================================================

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger("discovery")


# =====================================================================
# Models
# =====================================================================

class InstanceInfo(BaseModel):
    name: str
    host: str
    port: int


class InstanceState:
    def __init__(self, name: str, host: str, port: int):
        self.name = name
        self.host = host
        self.port = port
        self.state = "CLOSED"  # CLOSED | OPEN | HALF_OPEN
        self.fail_count = 0
        self.last_state_change = time.time()

    def to_dict(self):
        return {
            "name": self.name,
            "host": self.host,
            "port": self.port,
            "state": self.state,
            "fail_count": self.fail_count,
        }


# =====================================================================
# Registry (in-memory)
# =====================================================================

registry: dict[str, InstanceState] = {}

UPSTREAM_PATH = "/etc/nginx/conf.d/upstreams.conf"
HEALTH_CHECK_INTERVAL = 10  # detik
FAIL_THRESHOLD = 3
COOLDOWN = 30  # detik


# =====================================================================
# Tulis ulang upstreams.conf
# =====================================================================

def write_upstreams():
    lines = ["upstream backend {"]
    for inst in registry.values():
        if inst.state in ("CLOSED", "HALF_OPEN"):
            lines.append(
                f"    server {inst.host}:{inst.port} max_fails=3 fail_timeout=30s;"
            )
    lines.append("}")
    content = "\n".join(lines) + "\n"

    # Atomic write: tulis ke temp file dulu, lalu rename
    dir_name = os.path.dirname(UPSTREAM_PATH)
    fd, tmp_path = tempfile.mkstemp(dir=dir_name, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, UPSTREAM_PATH)
    except Exception:
        os.unlink(tmp_path)
        raise

    active = len([i for i in registry.values() if i.state in ("CLOSED", "HALF_OPEN")])
    logger.info("upstreams.conf updated: %d active servers", active)


# =====================================================================
# Reload Nginx via Docker socket HTTP API
# =====================================================================

def reload_nginx():
    import json

    try:
        with httpx.Client(transport=httpx.HTTPTransport(uds="/var/run/docker.sock"), timeout=10.0) as client:
            resp = client.post(
                "http://localhost/containers/gateway/exec",
                content=json.dumps({
                    "Cmd": ["nginx", "-s", "reload"],
                    "AttachStdout": False,
                    "AttachStderr": False,
                }),
                headers={"Content-Type": "application/json"},
            )
            resp_json = resp.json()
            if "Id" not in resp_json:
                logger.error("nginx reload exec failed: %s", resp_json)
                return
            exec_id = resp_json["Id"]

            client.post(
                f"http://localhost/exec/{exec_id}/start",
                content=json.dumps({"Detach": True}),
                headers={"Content-Type": "application/json"},
            )

        logger.info("nginx reloaded successfully")
    except Exception as e:
        logger.error("nginx reload failed: %s", e)


# =====================================================================
# Health Check Loop + Circuit Breaker
# =====================================================================

async def health_check_loop():
    while True:
        await asyncio.sleep(HEALTH_CHECK_INTERVAL)

        if not registry:
            continue

        async with httpx.AsyncClient(timeout=5.0) as client:
            for inst in list(registry.values()):
                url = f"http://{inst.host}:{inst.port}/health"
                try:
                    resp = await client.get(url)
                    if resp.status_code == 200:
                        if inst.state == "HALF_OPEN":
                            inst.state = "CLOSED"
                            inst.fail_count = 0
                            inst.last_state_change = time.time()
                            logger.info("[circuit-breaker] %s HALF_OPEN -> CLOSED (probe succeeded)", inst.name)
                            write_upstreams()
                            reload_nginx()
                        elif inst.state == "CLOSED":
                            inst.fail_count = 0
                    else:
                        inst.fail_count += 1
                        logger.warning("[circuit-breaker] %s health check failed (HTTP %d, fail_count=%d/%d)",
                                       inst.name, resp.status_code, inst.fail_count, FAIL_THRESHOLD)
                        if inst.state == "CLOSED" and inst.fail_count >= FAIL_THRESHOLD:
                            inst.state = "OPEN"
                            inst.last_state_change = time.time()
                            logger.error("[circuit-breaker] %s CLOSED -> OPEN (removed from upstream, fail_count=%d)",
                                         inst.name, inst.fail_count)
                            write_upstreams()
                            reload_nginx()
                        elif inst.state == "HALF_OPEN":
                            inst.state = "OPEN"
                            inst.last_state_change = time.time()
                            logger.error("[circuit-breaker] %s HALF_OPEN -> OPEN (probe failed)", inst.name)
                            write_upstreams()
                            reload_nginx()
                except Exception as e:
                    inst.fail_count += 1
                    logger.warning("[circuit-breaker] %s health check error: %s (fail_count=%d/%d)",
                                   inst.name, e, inst.fail_count, FAIL_THRESHOLD)
                    if inst.state == "CLOSED" and inst.fail_count >= FAIL_THRESHOLD:
                        inst.state = "OPEN"
                        inst.last_state_change = time.time()
                        logger.error("[circuit-breaker] %s CLOSED -> OPEN (unreachable, fail_count=%d)",
                                     inst.name, inst.fail_count)
                        write_upstreams()
                        reload_nginx()
                    elif inst.state == "HALF_OPEN":
                        inst.state = "OPEN"
                        inst.last_state_change = time.time()
                        logger.error("[circuit-breaker] %s HALF_OPEN -> OPEN (probe failed)", inst.name)
                        write_upstreams()
                        reload_nginx()

        # Cooldown check -> HALF_OPEN
        now = time.time()
        for inst in registry.values():
            if inst.state == "OPEN" and (now - inst.last_state_change) >= COOLDOWN:
                inst.state = "HALF_OPEN"
                inst.last_state_change = now
                logger.info("[circuit-breaker] %s OPEN -> HALF_OPEN (cooldown expired, probing...)", inst.name)


# =====================================================================
# FastAPI App
# =====================================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("discovery service starting")
    task = asyncio.create_task(health_check_loop())
    yield
    task.cancel()
    logger.info("discovery service stopped")


app = FastAPI(title="Service Discovery", version="1.0.0", lifespan=lifespan)


# =====================================================================
# Middleware: Request Logging
# =====================================================================

@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration_ms = round((time.time() - start_time) * 1000, 2)

    logger.info(
        "request: %s %s -> %d (%sms)",
        request.method,
        request.url.path,
        response.status_code,
        duration_ms,
    )
    return response


@app.get("/health")
def health():
    return {"status": "ok", "registry_size": len(registry)}


@app.post("/register")
def register(instance: InstanceInfo):
    is_reregister = instance.name in registry
    registry[instance.name] = InstanceState(
        name=instance.name,
        host=instance.host,
        port=instance.port,
    )
    action = "re-registered" if is_reregister else "registered"
    logger.info("[registry] %s: %s @ %s:%d", action, instance.name, instance.host, instance.port)
    write_upstreams()
    reload_nginx()
    return {"status": action, "instance": instance.name}


@app.delete("/register")
def unregister(instance: InstanceInfo):
    if instance.name in registry:
        del registry[instance.name]
        logger.info("[registry] unregistered: %s", instance.name)
        write_upstreams()
        reload_nginx()
        return {"status": "unregistered", "instance": instance.name}
    logger.warning("[registry] unregister failed: %s not found", instance.name)
    return {"status": "not_found", "instance": instance.name}


@app.get("/registry")
def get_registry():
    return {
        "instances": [inst.to_dict() for inst in registry.values()],
        "count": len(registry),
    }
