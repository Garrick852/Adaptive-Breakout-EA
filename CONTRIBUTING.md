# Contributing

Thanks for contributing! This project emphasizes reproducibility and diagnostics.

---

## 🌱 Branching and Pull Requests
- Create feature branches from `main`.
- Keep PRs small and focused; include diagnostic artifacts and tests.
- Use the PR template and ensure all checklist items are complete.

---

## 🧹 Code Quality
- Run `make setup` then `make lint` and `make test`.
- Add unit tests for new logic (prefer small, deterministic tests).
- Keep functions single-responsibility; avoid implicit global state.
- Document changes clearly in code comments.

---

## ⚙️ Configs and Schemas
### Configs:
- Place demo configs in `configs/demo`.
- Update or add JSON Schemas in `configs/schema` when introducing new fields.
- Validate configs with the following command:
    ```bash
    python python/tools/validate_configs.py
    ```

### Dashboards and Glyphs:
- Use `dashboards/multi_run/render_matrix.py` for demo glyphs.
- Update golden files under `dashboards/glyphs/expected` when outputs change.
- Provide rationale in your PR if golden files are updated.

---

## ✅ Continuous Integration
- Ensure the GitHub Actions workflow passes on your branch:
  - **Linting and type-checks**
  - **Config schema compliance**
  - **Glyph rendering vs golden comparison**
- Artifacts should upload cleanly and inspect if necessary.

---

## 🔍 Reviews
Reviewers will verify:
- Code clarity and maintainability.
- Tests that cover new logic.
- Schema compliance.
- Glyph determinism.
- Risk management consistency.

---

By following these guidelines, you help make this project maintainable, reliable, and adaptive to changes. Let’s build something great together!