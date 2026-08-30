# Security Policy

Report vulnerabilities privately through GitHub Security Advisories. Do not open a public issue containing an exploit, token, private repository name, or unreleased vulnerability detail.

The project supports the latest tagged release. Local hooks are an early-feedback mechanism, not a security boundary. Public-repository rulesets and required CI provide the remote enforcement boundary; GitHub Free private repositories have reduced enforcement.

Release workflows use the repository `GITHUB_TOKEN`, pin third-party Actions to full commit SHAs, create draft releases, and reject replacement of published assets.

