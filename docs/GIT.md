# Git and releases

Same commit policy as Pendulum Arc / Corten: **tag-line commits only**.

```
[ADD] Short imperative summary
[TST] Cover access boundary
```

Allowed tags: `[ADD] [UPD] [FIX] [DEL] [REF] [DOC] [TST] [CFG] [DEP] [SEC] [PRF] [REV]`

## Rules

- Every line is a tag line; one tag per line; ≤72 chars; no trailing period
- No free-form body
- No AI/Cursor co-author trailers
- Install hooks: `./scripts/install-hooks.sh`
- Branches: `feature/<slug>`, `fix/<slug>` from `main`; squash-merge preferred
- PR titles use the same tag-line format

Enforced by [`.githooks/commit-msg`](../.githooks/commit-msg). Template: [`.gitmessage`](../.gitmessage).

## Examples

```
[SEC] Add Dependabot CI and release checksum verification
[CFG] Pin prometheus and grafana compose image tags
[DOC] Document private vulnerability reporting
```

Multiple tags in one commit (one per line):

```
[ADD] Verify cardano-node downloads against sha256sums
[CFG] Pin Guild scripts to a commit hash
[DOC] Link SECURITY.md from the README
```

## Releases (node pin, not app SemVer)

This toolkit pins **Cardano node** (and related stack) versions via `NODE_VERSION`
in `env.example` / `env.docker` and matching manifests under
`scripts/test/releases/`. Bumping a release means updating those pins and
running `./scripts/test.sh smoke` - not publishing a GitHub Release unless you
want external notes.

Annotated tags are optional for milestone markers:

```bash
git tag -a v11.1.2-scripts -m "[CFG] Align scripts with node 11.1.2"
git push origin main --tags
```
