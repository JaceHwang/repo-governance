# Repository Governance

Repository-native Git commit, branch, version, and release governance for Codex-driven projects. The policy is vendored into each repository, so local hooks and GitHub CI execute the same reviewed code without a hosted service.

[简体中文](README.zh-CN.md)

## Guarantees

- Short-lived `codex/<type>/<kebab-case>` branches and Conventional Commit messages.
- Safe, deterministic formatting before commit; semantic mistakes stop the commit instead of being guessed.
- Pull-request CI validates every commit and the squash title, even when a local hook was bypassed.
- Release Please controls SemVer, changelog updates, tags, and draft releases.
- Atomic releases by default, with an opt-in staged platform mode that never overwrites published assets.

Git hooks are local and must be activated after each clone. Public GitHub repositories can add rulesets as the non-bypassable remote gate. GitHub Free private repositories cannot enforce those rules remotely; `./governance doctor` reports that limitation rather than overstating protection.

## Install in a repository

Use the installed `$repository-governance` Codex skill, or run the installer from a trusted checkout:

```bash
./scripts/install.sh --target /absolute/path/to/repository
cd /absolute/path/to/repository
./governance bootstrap
./governance doctor
```

The installer preserves repository-specific policy and adapters during updates:

```bash
./scripts/install.sh --target /absolute/path/to/repository --update
```

Configure these tracked adapters in the governed repository:

| Adapter | Contract |
| --- | --- |
| `format-staged` | Format staged files deterministically; never stage files itself. |
| `check-fast` | Run fast static or version consistency checks. |
| `check-full` | Run every deterministic pre-push/CI test. |
| `build-release` | Write immutable release assets below `.dist/release/`. |
| `verify-release` | Verify checksums, provenance, platform evidence, and tag/version identity. |

Use `.governance/policy.sh` only for repository-specific overrides. Template defaults remain in `.governance/policy.defaults.sh` and are safely upgraded.

## Daily workflow

```bash
git switch -c codex/feat/add-example
./governance doctor
# edit and test
git commit -m "feat(core): add example"
./governance check all
git push -u origin codex/feat/add-example
```

Open a PR whose title is also a Conventional Commit header. Public repositories should apply the generated GitHub policy only after both required checks have completed successfully:

```bash
./scripts/configure-github.sh --repo OWNER/REPO --dry-run /tmp/governance-policy
./scripts/configure-github.sh --repo OWNER/REPO --apply
```

The active policy requires PRs with squash merging, `governance / policy`, and `verify / project`; blocks direct updates, deletion, and force-pushes on `main`; and makes `v*` tags immutable.

## Versions and releases

Ordinary commits do not edit the product version. Release Please maintains one release PR from commits on `main`:

- `fix`, `perf`, `revert` → patch
- `feat` → minor
- breaking change below `1.0.0` → minor
- breaking change at or above `1.0.0` → major
- documentation, tests, style, build, CI, and chores do not release by themselves

The release PR updates `version.txt`, `.release-please-manifest.json`, and `CHANGELOG.md`. Repository-specific `extra-files` keep other version sources synchronized.

For staged releases, set `RELEASE_MODE=staged` and declare `RELEASE_PLATFORMS` in `.governance/policy.sh`. Run **Publish release platform** for an existing tag. The workflow rejects unknown platforms and existing asset names, builds from the exact tag, updates the platform status matrix, and publishes the draft after the first successful platform.

Prereleases use temporary `codex/prerelease/alpha`, `codex/prerelease/beta`, or `codex/prerelease/rc` branches. Stable releases continue from `main`.

## Development

Run the complete suite:

```bash
sh tests/run.sh
go run github.com/rhysd/actionlint/cmd/actionlint@v1.7.7 .github/workflows/*.yml
```

See [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md).

Repository-native Git commit, branch, version, and release governance for Codex-driven projects.
