import os

from fastapi import APIRouter

router = APIRouter(tags=["instance"])


@router.get("/instance")
def get_instance():
    return {"instance": os.getenv("INSTANCE_NAME", "api")}
