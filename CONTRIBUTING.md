# Contributing to LocalAI Stack

Thank you for your interest in contributing! This document explains how to report bugs, suggest features, and submit code changes.

## Table of contents

- [Code of conduct](#code-of-conduct)
- [Reporting bugs](#reporting-bugs)
- [Suggesting features](#suggesting-features)
- [Contributing code](#contributing-code)
- [Development setup](#development-setup)
- [Commit conventions](#commit-conventions)
- [Security vulnerabilities](#security-vulnerabilities)

---

## Code of conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating you agree to uphold these standards.

---

## Reporting bugs

1. Search [existing issues](https://github.com/k-trimbuddhimatta/localai/issues) first — your bug may already be reported.
2. If not, open a new issue using the **Bug Report** template.
3. Include the output of `bash check.sh` in your report — it provides the exact environment details needed to reproduce the issue.

---

## Suggesting features

1. Search [existing issues](https://github.com/k-trimbuddhimatta/localai/issues) to avoid duplicates.
2. Open a new issue using the **Feature Request** template.
3. Describe the problem you are trying to solve, not just the solution — this helps evaluate alternatives.

---

## Contributing code

### 1. Fork and clone

```bash
git clone https://github.com/<your-username>/localai.git
cd localai
```

### 2. Create a branch

Branch from `dev`, not `main`:

```bash
git checkout dev
git pull origin dev
git checkout -b feat/your-feature-name
# or: fix/short-description
```

### 3. Make your changes

- Test your changes with `bash check.sh` and `bash setup.sh` on a clean environment
- Do not commit `.env` files or any credentials — the `.gitignore` covers this but double-check
- Keep changes focused: one feature or fix per PR

### 4. Commit

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add support for custom Ollama port
fix: setup.sh fails when LITELLM_SALT_KEY contains special chars
docs: clarify RAM requirements for 14b models
chore: update docker-compose healthcheck timeout
```

### 5. Open a pull request

- Target branch: `dev` (never `main` directly)
- Fill in the PR template completely
- Link any related issues with `Closes #<number>`

---

## Development setup

**Requirements:** macOS, Docker Desktop, Ollama installed.

```bash
# Run the pre-flight check
bash check.sh

# Run the setup wizard
bash setup.sh

# View logs
docker compose logs -f litellm

# Stop everything
bash stop.sh
```

To test changes to `setup.sh` or `check.sh` without a full teardown:

```bash
# Validate bash syntax
bash -n setup.sh
bash -n check.sh

# Test with a fresh .env
mv .env .env.bak && bash setup.sh
```

---

## Commit conventions

| Prefix | When to use |
|--------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation only |
| `chore:` | Maintenance (deps, config) |
| `refactor:` | Code change with no behavior change |
| `test:` | Adding or updating tests |

Breaking changes: add `!` after the prefix — `feat!: rename env variable`.

---

## Security vulnerabilities

**Do not open a public issue for security vulnerabilities.**

See [SECURITY.md](SECURITY.md) for the responsible disclosure process.
