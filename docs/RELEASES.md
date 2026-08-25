# GitHub releases

[Full docs index](README.md) · [Test manifests (`NODE_VERSION`)](../scripts/test/releases/README.md) · [Smoke / integration](TESTS.md)

This repo has **two** version lines. Do not mix them up.

| What | Example | Meaning |
|------|---------|---------|
| GitHub release tag | `v1.0.3` | A cut of **this toolkit** (scripts, docs, configs). Operators `git checkout` this tag. Published at [GitHub Releases](https://github.com/devhalls/cardano-stake-pool-operator-scripts/releases). |
| Node contract | `NODE_VERSION=11.0.1` | Pinned cardano-node (and matching env / configs / smoke manifests). One GitHub tag can stay on the same node contract. |

Bumping cardano-node still follows [scripts/test/releases/README.md](../scripts/test/releases/README.md). This page is only how to publish the next **`v1.0.x`** on GitHub.

---

## When to cut a repo release

Cut a tag after `main` has landed work operators should run, for example:

- Grafana / Prometheus / monitoring install fixes
- db-sync host migration docs or scripts
- topology / metrics / tracing config fixes
- registration or governance script fixes

You do **not** need a new `NODE_VERSION` (or copied manifests) if the node pin is unchanged.

---

## Merge checklist (before the tag)

1. Merge every branch that belongs in the release into `main` (PR, then merge). For the next cut that includes:
   - everything already on `origin/main` since `v1.0.3`
   - `fix/grafana-import` (Grafana 11 metric names, portable datasources, Grafana 13 install / provisioning)
2. On `main`, set the clone pin in [deployment/01-cardano-node-installation.md](deployment/01-cardano-node-installation.md) to the **new** tag (`git checkout v1.0.4`).
3. Confirm env pins still match the last GitHub notes (update the notes if a pin moved):

   ```shell
   grep -E '^(NODE_VERSION|MITHRIL_VERSION|DB_SYNC_VERSION)=' env.example
   ```

4. Run smoke (required). Integration only if a synced node socket is available.

   ```shell
   ./scripts/test.sh smoke
   # or
   ./docker/script.sh test.sh smoke
   ```

5. Fast-forward local `main` and confirm a clean tree:

   ```shell
   git checkout main
   git pull --ff-only origin main
   git status
   git log v1.0.3..HEAD --oneline
   ```

---

## Publish the GitHub release

Tags are **`vMAJOR.MINOR.PATCH`**. Next after [v1.0.3](https://github.com/devhalls/cardano-stake-pool-operator-scripts/releases/tag/v1.0.3) is **`v1.0.4`**.

From an up-to-date `main`:

```shell
git tag -a v1.0.4 -m "v1.0.4"
git push origin v1.0.4

gh release create v1.0.4 --title "v1.0.4" --notes "$(cat <<'EOF'
Cardano SPO operational scripts. Monitoring and operator-script fixes for v1.0.4.

**Min version support:**

- Cardano node **11.0.1**
- Mithril node **2537.0**
- Midnight node **0.12.0**
- DBSync **13.7.0.5** (schema includes 13.7.1.0 epoch fix migration)

**Network support:**

- Mainnet
- PreProd
- Preview
- SanchoNet

**Device Support:**

- Linux
- MacOS
- Docker local tester only

**Changes since v1.0.3:**

- Grafana dashboard queries for cardano-node 11 metric names (`*_counter` / inbound peers)
- Portable Grafana datasources (`${DS_PROMETHEUS}` / `${DS_CSV}`); Prometheus provisioned by name (Grafana 13 rejects mismatched UIDs)
- `install grafana` works on a producer that hosts Grafana; skips package upgrade on re-run; uses `grafana cli` on Grafana 13
- db-sync host migration
- Topology / metrics / tracing config fixes
- DRep deregistration deposit handling

**Support us:**

If you find this useful, please delegate to Upstream UPSTR Stake pool to help us improve these tools:

https://upstream.org.uk
EOF
)"
```

Keep the **Min version support** / **Network** / **Device** / **Support us** blocks in the same shape as v1.0.2 and v1.0.3. Edit **Changes since** to match what actually merged.

Do not force-push tags. If a tag is wrong, publish `v1.0.5`.

---

## After publish

Operators already on a clone:

```shell
git fetch --tags
git checkout v1.0.4
```

New install (see [Cardano Node installation](deployment/01-cardano-node-installation.md)):

```shell
git clone https://github.com/devhalls/spo-operational-scripts.git .
git checkout v1.0.4
```

---

## Next release after this one

1. Repeat the merge checklist.
2. Bump the tag (`v1.0.5` or `v1.1.0` if you want a minor for a node-contract bump).
3. If `NODE_VERSION` changes, do the manifest copy in [scripts/test/releases/README.md](../scripts/test/releases/README.md) **before** tagging.
4. Refresh **Min version support** and the install-doc `git checkout` line.
