---
name: repository-governance
description: Use when initializing, checking, committing, pushing, merging, versioning, or releasing a Git repository that should follow the JaceHwang repository-governance policy.
---

# Repository Governance

Use the repository's tracked governance entrypoint as the source of truth. The skill guides Codex; hooks and CI enforce the policy.

## Entering a repository

1. If `./governance` exists, run `./governance doctor` before the first code-changing action.
2. If hooks are inactive, run `./governance bootstrap`, then repeat doctor.
3. If governance is absent and the user asked to initialize it, install from `JaceHwang/repo-governance`, inspect the generated policy and adapters, then run its tests. Do not install or modify repository settings without authorization.

## Development

- Never develop or commit on `main`. Use `codex/<type>/<kebab-case>`.
- Use an English Conventional Commit header and put Chinese context in the PR body when useful.
- Never pass `--no-verify`, weaken an adapter, or omit a failing check. Apply deterministic fixes, stage the reviewed result, and retry normally.
- Before pushing, run `./governance check all`. Open a PR and use its Conventional Commit title as the squash commit title.

## Version and release

- Do not bump product versions in ordinary feature commits.
- Review the Release Please PR for the computed SemVer, generated changelog, synchronized version files, and green required checks.
- For staged repositories, publish a platform only from the existing release tag. Never overwrite an uploaded asset; code changes require a new version.
- Use `codex/prerelease/alpha`, `beta`, or `rc` only when the user explicitly requests a prerelease.

If GitHub cannot enforce rules for a private repository, report the limitation exactly as doctor reports it. Do not describe local hooks as unbypassable remote protection.
