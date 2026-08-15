# AGENTS.md

This file provides guidance to AI coding agents working in this repository.

## What this repository is

`hive-apps` is the declarative configuration for a k3s homelab, managed through **heqet**. Heqet runs as a Config Management Plugin (CMP) inside ArgoCD: at sync time the heqet CMP generates ArgoCD `Application` (and `AppProject`/`Namespace`) resources from the per-project YAML files in this repo, using ArgoCD's app-of-apps pattern. There is no traditional build, test, or lint step — validation is done via `helm template` dry-runs and by ArgoCD reconciling changes. Renovate (`renovate.json`) opens PRs for dependency/chart bumps.

Tooling references: heqet (`https://github.com/lib42/heqet`, pinned in `Heqetfile`), Renovate (`renovate.json`), ansible (`ansible/` for the bare k3s host).

## Repository layout

- `Heqetfile` — required; pins the heqet version/path/values used by the CMP to render ArgoCD apps.
- `values.yaml` — heqet defaults applied to every generated ArgoCD `Application` (ArgoCD project, sync policy `prune`/`selfHeal`, retry backoff). Edit here to change cluster-wide sync behavior.
- `resources/` — cross-cutting heqet inputs:
  - `repos.yml` — named Helm/Git repos added to ArgoCD (e.g. `bjw-s`, `bitnami`). Referenced from project files via `repo: <name>` shorthand.
  - `networkpolicy.yml` — predefined NetworkPolicy **groups** and **rules** (internet egress via proxy, ingress from `ingress-external`, S3, etc.). Applied per-project.
  - `snippets/` — reusable value fragments (e.g. `noRoot`, `tmpdirs`) injected into app `values`.
- `projects/<name>/` — one directory per ArgoCD "project"/app group:
  - `project.yaml` (or `project.yml`) — the heqet definition: `config.description` and an `apps:` list. Each app specifies `repo`/`repoURL`, `chart` or git `path`, `targetRevision`, optional `namespace`, `secrets`, `parameters`, `syncWave`, `ignoreDiff`.
  - `values/*.yml` — Helm values passed to each app. Most use the **bjw-s `app-template`** chart (see the `# yaml-language-server: $schema=.../common-VERSION/...` line at the top — keep the schema version in sync with `targetRevision`).
  - `manifests/*.yaml` — raw Kubernetes manifests (CRs, backups) deployed alongside an app.
- `.archive/` — retired projects (kept for reference, ignored by Renovate).
- `ansible/` — `k3s-playbook.yml` provisions the bare-metal host (k3s version, registries mirror, CNI/servicelb disabled so Cilium + MetalLB take over).

## Key architectural concepts

- **heqet generates, you don't:** the heqet CMP renders ArgoCD Applications from `projects/*` at sync time. You never edit ArgoCD objects directly; you edit the heqet source (project files, values, resources) and ArgoCD reconciles.
- **Charts vs git paths:** `chart:` (with optional `repo:` shorthand from `repos.yml`) pulls a Helm chart; omitting `chart` and setting `path:` deploys a raw git repo / manifest tree.
- **Secrets are declared, not stored.** `secrets:` blocks in `project.yaml` (e.g. `- name: hermes-agent; keys: [GITHUB_TOKEN]`) declare the Kubernetes `Secret` + `ExternalSecret` heqet should create. `fromApp: <other-app>` reuses another app's secret. Actual values live in Vault and are surfaced by `vault-secrets-operator` (see `projects/vault`). Never commit secret values.
- **`targetRevision` is the version pin.** Bumping a chart/image revision here is the primary upgrade mechanism; Renovate automates it.
- **`syncWave` + `ignoreDiff`:** negative waves (`-3`, `-2`) deploy infra (vault, cert-manager) before apps; `ignoreDiff` suppresses noisy drift (webhook CA bundles, generated secrets).
- **NetworkPolicy is opt-in per project** via the named groups/rules in `resources/networkpolicy.yml`.

## Common tasks

- **Add an app:** create `projects/<name>/project.yaml` with an `apps:` entry (use `repo: bjw-s; chart: app-template` pattern), add a matching `values/*.yml`, and ArgoCD syncs it via the CMP. For CNPG/CloudNativePG, Garage, etc., add supporting CRs under `manifests/`.
- **Upgrade a dependency (the normal change):** bump `targetRevision` in the relevant `project.yaml` (or let Renovate raise a PR). Validate before committing:
  - `helm template <release> <repo>/<chart> --version <rev> -f projects/<name>/values/<file>.yml` (for app-template charts, repo `https://bjw-s-labs.github.io/helm-charts`)
  - `kubectl apply --dry-run=server -f <generated-or-sync-manifest>` to sanity-check the install
- **Inspect live state:** standard `kubectl`/`argocd` against the homelab cluster. Secrets come from Vault via `vault-secrets-operator`.
- **Provision/repair the host:** `ansible/` playbook (k3s version, registry mirror `reg.dc`, CNI).

## Conventions to preserve

- Commit style (see history): `fix(scope): ...`, `update(...) ...`, `chore(deps): update docker image ... (#N)` for Renovate. Scope loosely matches the app/project.
- Renovate (`renovate.json`) manages `targetRevision` bumps in `projects/*/values/*.y*ml` (helm-values) and `project.y*ml` (custom regex for `chart`/`targetRevision`). It ignores `ansible/`, `.archive/`, and top-level `kubernetes` paths in `projects`.
- The `app-template` values files carry a JSON-schema header pinning the `common` library version used by `targetRevision` — update both together.
