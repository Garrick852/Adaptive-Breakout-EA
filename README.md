# Adaptive Breakout AI

A diagnostics-first trading system scaffold with an MQL5 EA, Python tooling, JSON Schemas, dashboards, and CI validation.

## Quick start
1. `make setup`
2. `make lint && make test`
3. `make glyphs` (renders demo glyphs and compares against golden)
4. Review [native and AOS-controlled modes](docs/NATIVE_MODE.md) before isolated MT5 testing.
   Execution defaults to disabled; selecting native mode is separate from arming.

## Repo map
- `eas/AdaptiveBreakoutAI`: EA source and docs
- `python`: tools, tests, and validators
- `configs`: demo configs and schemas
- `dashboards`: glyph renderer and expected goldens
- `.github/workflows`: CI pipeline

## CI
- Lint, type-check, tests
- Config validation via JSON Schema
- Glyph rendering and golden comparison
- Artifacts uploaded for inspection

## Contributing
See `CONTRIBUTING.md` and `docs/ContributorHub.md`. Use `.github/pull_request_template.md` for PRs.