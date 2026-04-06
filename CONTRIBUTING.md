# Contributing to {{SDK_NAME}} SDK

Thank you for your interest in contributing to the {{SDK_NAME}} SDK!

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/{{GITHUB_ORG}}/{{SDK_SLUG}}-sdk.git
   cd {{SDK_SLUG}}-sdk
   ```

2. Install Task runner:
   ```bash
   go install github.com/go-task/task/v3/cmd/task@latest
   ```

3. Set up the development environment:
   ```bash
   task setup
   ```

## Development Workflow

1. Create a feature branch from `main`
2. Make your changes
3. Ensure tests pass: `task test`
4. Ensure version consistency: `task version-check`
5. Submit a pull request

## Code Standards

- All SDKs must maintain 80% minimum test coverage
- Follow the existing patterns in each language SDK
- Keep public API signatures consistent across all languages
- Run `task validate` before submitting PRs

## Versioning

- All SDKs share a single VERSION file at the repo root
- Use `task bump-version VERSION=x.y.z` to update versions
- Never manually edit version strings in individual SDK files

## Commit Messages

- Use clear, concise commit messages
- Commit file-by-file (atomic commits)
- Do not include co-authorship tags

## Reporting Issues

Please use GitHub Issues to report bugs or request features.
