# Contributing

Keep changes focused, testable, and repository-agnostic.

1. Create `codex/<type>/<kebab-case>` from `main`.
2. Run `./governance bootstrap` and `./governance doctor`.
3. Add a failing behavior test before changing executable governance logic.
4. Run `sh tests/run.sh` and actionlint.
5. Open a PR with a Conventional Commit title and describe the user impact, risks, and verification.

Do not add language-specific behavior to the governance core. Put project behavior behind an adapter. Never introduce a release path that overwrites an existing asset or mutates an existing version tag.

