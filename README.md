# Personal Career Agent

Personal autonomous career-search and interview assistant.

## Architecture

GitHub
→ GitHub Actions
→ OpenClaw
→ OpenRouter
→ GitHub repository
→ GitHub Pages

## Candidate

10+ years experience.

Target roles:

- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

Preferred location:

Remote India

## Security

The agent is designed to execute in GitHub Actions.

It must NOT:

- access the user's Mac
- access the local filesystem
- access SSH
- access Keychain
- access browser passwords
- access Gmail
- send external messages automatically
- contact recruiters automatically
- apply automatically
- spend money
- modify GitHub workflow files

External actions require human confirmation.

## Important

This bootstrap intentionally DOES NOT create files
under `.github/workflows/`.

Workflow files should be managed separately.

## Model

OpenRouter is used as the model provider.

No local Ollama installation is required.

## Website

The `site/` directory contains the GitHub Pages
frontend.

## Data

`data/` contains generated career-agent output.

## Memory

`memory/` contains agent preferences and learning state.
