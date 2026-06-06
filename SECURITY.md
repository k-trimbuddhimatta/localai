# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `0.x.x` (current) | ✅ |

## Reporting a vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

If you discover a security issue in this project — such as accidental credential exposure, authentication bypass, or container escape — please report it privately:

**Email:** chemapolo@gmail.com  
**Subject:** `[localai] Security vulnerability report`

Include:
- A description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept (if safe to share)
- Your suggested fix, if you have one

You will receive an acknowledgement within **72 hours** and a resolution timeline within **7 days**.

## Scope

This project handles API keys for cloud providers (Anthropic, OpenAI, Google). Security-relevant areas include:

- `.env` file handling and gitignore coverage
- LiteLLM master key exposure
- Docker network isolation
- `setup.sh` and `check.sh` input handling

## Out of scope

- Vulnerabilities in upstream dependencies (LiteLLM, Ollama, PostgreSQL, Docker) — report those to their respective projects
- Issues requiring physical access to the machine

## Disclosure policy

We follow **coordinated disclosure**: once a fix is available, we will publish a security advisory on GitHub and credit the reporter (unless anonymity is requested).
