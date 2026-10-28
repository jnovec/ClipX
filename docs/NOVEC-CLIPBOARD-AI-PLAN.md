# NOVEC Clipboard AI — project plan

Tracking: https://trello.com/b/sBH9axYZ/novec-clipboard-ai

## Sources
- [ClipX](https://github.com/jnovec/ClipX): Swift macOS clipboard shelf, history, images and search.
- [ClipboardAutomator](https://github.com/jnovec/ClipboardAutomator): clipboard polling and external command execution.

## Target
One native macOS app: watch clipboard changes; persistent history of text, links and images; per-item delete; n8n event integration; local Ollama classification, suggested actions and destination. Do not automatically move files or send sensitive clipboard content to external services without explicit consent.

## Tasks
- [ ] Merge the best of both applications into one source tree.
- [ ] Add persistent clipboard history and per-item delete.
- [ ] Add authenticated, configurable n8n webhook integration, retry and privacy controls.
- [ ] Add local Ollama classification and suggestions for each new item.
- [ ] Build .app and test text/image capture, history, deletion, n8n and AI.

## Current status (2026-10-28)
- Mac workspace prepared: `~/Projects/NOVEC-Clipboard-AI/`.
- ClipX source copied to `app/`.
- Git clone of private ClipboardAutomator blocked by Git authentication; its source is accessible via GitHub connector.
- No merged build or integration tests completed yet.
