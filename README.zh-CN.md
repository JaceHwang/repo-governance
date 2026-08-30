# Repository Governance

面向 Codex 驱动开发的仓库级 Git 提交、分支、版本和发布治理工具。每个项目都保存并执行自己的 hooks、策略和 CI，不依赖常驻在线服务。

## 能解决什么

- 强制 `codex/<type>/<kebab-case>` 短期分支和 Conventional Commits。
- 提交前只自动修复无歧义格式；无法可靠判断的语义错误会阻止提交并让 Codex重试。
- PR CI 重新校验全部 commits 和 squash 标题，本地 hook 被绕过时仍能发现问题。
- Release Please 统一计算 SemVer、更新 CHANGELOG、创建 tag 和 draft Release。
- 默认原子发布，也支持同一 tag 下按平台分批补充不可覆盖的制品。

Git hook 在每次 clone 后都需要初始化。GitHub Free 的公开仓库可通过 ruleset 实现远端强制；免费私有仓库无法获得同等级强制能力，`./governance doctor` 会明确报告该限制。

## 接入仓库

优先让 Codex使用 `$repository-governance` skill，也可以从可信母版 checkout 执行：

```bash
./scripts/install.sh --target /仓库绝对路径
cd /仓库绝对路径
./governance bootstrap
./governance doctor
```

升级时使用 `--update`；项目自己的 `.governance/policy.sh` 和 adapters 不会被覆盖。项目只需实现五个边界：`format-staged`、`check-fast`、`check-full`、`build-release`、`verify-release`。

日常开发必须走 `codex/<type>/<slug>` → commit → `./governance check all` → PR → squash merge。普通 commit 不手改产品版本，版本统一由 release PR 更新。

在公开仓库中，等 `governance / policy` 与 `verify / project` 已经成功运行后，再启用远端规则：

```bash
./scripts/configure-github.sh --repo OWNER/REPO --dry-run /tmp/governance-policy
./scripts/configure-github.sh --repo OWNER/REPO --apply
```

完整配置、发布和开发说明见 [英文 README](README.md)。

