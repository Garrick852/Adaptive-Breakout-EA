from dashboards.backend.models.router_config import RouterConfig
from dashboards.backend.services.config_service import load_and_validate

def get_router_config() -> RouterConfig:
    return load_and_validate(
        config_filename="router_demo.json",
        schema_filename="router.schema.json",
        model=RouterConfig,
    )
