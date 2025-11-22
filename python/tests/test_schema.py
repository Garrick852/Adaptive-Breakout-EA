import glob

import pytest
import yaml

REQUIRED = {"name": str, "symbols": list, "risk": dict, "mode": str}

@pytest.mark.parametrize("path", glob.glob("configs/demo/*.yaml"))
def test_demo_config_schema(path):
    with open(path) as f:
        data = yaml.safe_load(f)
    missing = [k for k in REQUIRED if k not in data]
    assert not missing, f"{path} missing keys: {missing}"
    for k, t in REQUIRED.items():
        assert isinstance(data[k], t), f"{path} wrong type for {k}: {type(data[k]).__name__}"