from dashboards.backend.models.signals_config import SignalsConfig
from dashboards.backend.services.config_service import load_and_validate


def get_signals_config() -> SignalsConfig:
    return load_and_validate(
        config_filename="signals_config.json",  # you can create this file later
        schema_filename="signals.schema.json",
        model=SignalsConfig,
    )
