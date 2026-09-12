# Personal Career Agent

Private personal job-search assistant.

Architecture:

GitHub
→ GitHub Actions
→ OpenClaw
→ OpenRouter
→ persistent repository state
→ GitHub Pages

No Gmail.
No Cloudflare.
No Ollama.
No local Mac execution.
No automatic applications.

The GitHub Pages site is a static dashboard.

GitHub Actions performs agent work.

OpenRouter is accessed only from GitHub Actions.

The OpenRouter API key must NEVER be placed in the Pages
frontend or committed to the repository.

The agent may analyze jobs and prepare recommendations,
but job applications and recruiter communication require
human confirmation.

## Initial profile

10+ years experience.

Target:
- Principal Software Engineer
- Staff Software Engineer
- Software Architect
- Associate Director
- Senior Engineering Manager

Location:
Remote India.

## Security

The agent must never access the user's Mac,
filesystem, Keychain, browser passwords or SSH credentials.
