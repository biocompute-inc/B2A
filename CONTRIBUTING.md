# Contributing Guidelines

👋 Welcome! Thanks for considering contributing.

## Branching
- `main`: production-ready code
- `dev`: integration branch
- `feature/<name>`: new features
- `bugfix/<name>`: fixes

## Workflow
1. Create a branch: `git checkout -b feature/your-feature`
2. Commit with clear messages (e.g., `feat: add upload progress bar`)
3. Push and open a PR **to `dev`**
4. Ensure:
   - Tests pass
   - Lint passes
   - PR references an issue (`Fixes #123`)
   - Template checklist is completed

## Code Style
- Follow project lint rules
- Add/update tests when changing behavior

## Reviews
- At least 1 approval required
- No direct commits to `main`
