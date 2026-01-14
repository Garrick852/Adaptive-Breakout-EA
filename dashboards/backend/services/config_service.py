import json
from pathlib import Path
from typing import Any

from dashboards.backend.config.settings import CONFIGS_DIR, SCHEMAS_DIR
from jsonschema import Draft7Validator
from pydantic import BaseModel, ValidationError


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)

def validate_with_schema(data: dict[str, Any], schema_file: str) -> None:
    schema_path = SCHEMAS_DIR / schema_file
    schema = load_json(schema_path)
    Draft7Validator(schema).validate(data)

def load_and_validate(
    config_filename: str,
    schema_filename: str,
    model: type[BaseModel],
) -> BaseModel:
    cfg_path = CONFIGS_DIR / config_filename
    data = load_json(cfg_path)
    # First validate with JSON Schema
    validate_with_schema(data, schema_filename)
    # Then coerce/validate with Pydantic
    try:
        return model.model_validate(data)
    except ValidationError as e:
        # Re-raise with clearer message
        raise ValueError(f"Pydantic validation failed for {config_filename}: {e}") from e
