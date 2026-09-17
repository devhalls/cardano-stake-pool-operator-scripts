# Contributing

## Commits

Tag-line commits only - same policy as Pendulum Arc. Full rules:
[`docs/GIT.md`](docs/GIT.md).

```bash
./scripts/install-hooks.sh
```

Example:

```
[SEC] Add Dependabot CI and release checksum verification
```

## Workflow

1. Branch `feature/<slug>` or `fix/<slug>` from `main`
2. Keep changes focused; update docs when behaviour changes
3. Run `./scripts/test.sh smoke` when touching env, services, configs, or build pins
4. Open a focused PR; title uses the same tag-line format

Security reports: [`SECURITY.md`](SECURITY.md).
