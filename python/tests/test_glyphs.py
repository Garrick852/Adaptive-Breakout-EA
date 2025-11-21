import pathlib

EXPECTED = {
    "EURUSD_demo.txt": "glyph:EURUSD:seed=101\n",
    "USDJPY_demo.txt": "glyph:USDJPY:seed=101\n",
    "XAUUSD_demo.txt": "glyph:XAUUSD:seed=101\n",
    "DriftDetected.txt": "glyph:DriftDetected:demo\n",
}

def test_expected_glyphs_exist_and_match():
    base = pathlib.Path("dashboards/glyphs/expected")
    for fname, content in EXPECTED.items():
        path = base / fname
        assert path.exists(), f"Missing glyph: {fname}"
        data = path.read_text()
        assert data == content, f"Glyph mismatch for {fname}: {data!r} != {content!r}"
