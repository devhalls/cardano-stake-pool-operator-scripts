# Security policy

## Reporting a vulnerability

Please **do not** open a public GitHub issue for security problems.

Use GitHub’s [private vulnerability reporting](https://github.com/devhalls/cardano-stake-pool-operator-scripts/security/advisories/new) for this repository, or email the maintainers via the Upstream contact channels listed in the README.

We aim to acknowledge reports within **7 days** and to share a remediation plan or fix timeline once the issue is confirmed.

## Scope

**In scope**

- Flaws in these scripts that could lead to key leakage, unintended transaction signing, or silent install of tampered binaries
- Supply-chain issues in download/install helpers shipped in this repo
- Accidental commitment or logging of secrets by the scripts themselves

**Out of scope**

- Operator misconfiguration (weak passwords, exposed Grafana/`0.0.0.0` binds, copying cold keys to hot hosts)
- Compromised operator machines, SSH keys, or third-party upstream release channels after checksum verification succeeds
- Vulnerabilities solely in Cardano node, Mithril, db-sync, Grafana, or other upstream binaries (report those upstream)

## Trust boundaries for operators

- Prefer **cold / hot key separation** as documented under `docs/registration/`
- Treat `env`, `$NETWORK_PATH/keys`, and any `*.skey` / private keys as secrets — never commit them
- Release downloads should verify against upstream SHA256 sums when published (see `download_release_file` in `scripts/common.sh`)
- Pool/DRep metadata URLs are operator-supplied content; treat them as untrusted input

## Maintainer checklist (GitHub settings)

After `gh auth login`, enable for this repo:

1. Dependabot alerts + Dependabot security updates
2. Secret scanning + push protection
3. Private vulnerability reporting
4. Branch protection on `main` (require PR; disallow force-push; optionally require the `CI` status check)
