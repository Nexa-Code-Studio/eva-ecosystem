---
name: prepare-pr
description: Validate branch naming, clean working tree, execute local tests, and generate a standardized Pull Request matching repository templates.
---

# Prepare PR Runbook

This skill verifies that the local workspace is ready for Pull Request creation, runs test verification, and outputs a formatted PR body.

## Execution

### 1. Dry-Run PR Preparation
```bash
python3 scripts/agentic/prepare-pr.py \
  --test-cmd "python3 -m unittest discover -s tests/agentic" \
  --dry-run
```

### 2. Standard PR Preparation
```bash
python3 scripts/agentic/prepare-pr.py \
  --test-cmd "python3 -m unittest discover -s tests/agentic"
```

The script links the relevant issue (`Closes #128`), lists commits on the branch, and includes the recorded test suite evidence.
