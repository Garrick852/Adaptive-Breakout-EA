---
name: Pull Request
about: Propose a change to the Adaptive-Breakout-EA project
title: ''
labels: ''
assignees: ''

---

### Description

*Please include a summary of the change and which issue is fixed. Please also include relevant motivation and context.*

*Closes # (issue)*

---

### Type of Change

*Please delete options that are not relevant.*

- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

---

### Contributor Workflow Checklist:

*This checklist ensures that new features are robust, testable, and integrate with our diagnostics systems.*

- [ ] **Code Quality**: My code follows the style guidelines of this project.
- [ ] **Self-Review**: I have performed a self-review of my own code.
- [ ] **Documentation**: I have commented my code, particularly in hard-to-understand areas.
- [ ] **Documentation**: I have made corresponding changes to the documentation.

---

### New Feature & Diagnostics Checklist:

*Complete this section if you are adding a new feature or changing diagnostic outputs.*

- [ ] **New Module**: Does this PR introduce a new module (e.g., a `.mqh` or Python file)?
  - *If yes, please list the new files here.*
- [ ] **New Diagnostic Glyphs**: Does this PR introduce or modify diagnostic glyphs?
  - *If yes, please answer the following:*
  - [ ] **Glyph Documentation**: I have added/updated the documentation for the new glyphs in the `dashboards/glyphs/expected/` directory.
  - **CI Validation**: I have confirmed that a GitHub Actions workflow validates the output of these glyphs during a test run.
- [ ] **Backtesting**: I have run a successful backtest with these changes and have attached the log or a summary of the results below.

---

### Test Configuration

*Please provide details on your test setup.*

*   **EA Version**:
*   **Symbol**:
*   **Timeframe**:
*   **Backtest Period**:

---

### Additional Context

*Add any other context about the pull request here.*
