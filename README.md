# Hive Apps

This is the [heqet](https://github.com/lib42/heqet) configuration for my k3s homelab.

## Overview

This repository is the single source of truth for everything that runs on the cluster. Heqet runs as a **Config Management Plugin (CMP) inside ArgoCD**: at sync time it generates ArgoCD `Application` (and `AppProject`/`Namespace`) resources from the YAML files in this repo, using ArgoCD's app-of-apps pattern. You edit the declarative source here; ArgoCD reconciles the cluster to match.

There is no build step. Dependency and chart upgrades are automated by Renovate (`renovate.json`), which opens PRs that bump `targetRevision` pins.

## How it works

`projects/` is the heart of this repository. Each subdirectory is a **project** — a group of related apps (e.g. `nextcloud`, `arrstack`, `vault`) — and is what heqet turns into an ArgoCD `AppProject` plus one `Application` per app. Everything the cluster runs is defined here; `resources/` and the root config files only provide shared inputs and defaults.

```
projects/<name>/project.yaml  ─┐
projects/<name>/values/*.yml  ─┤  heqet CMP (in-cluster) ──▶ ArgoCD Applications ──▶ cluster
resources/*                   ─┘
```

- `projects/<name>/` — the unit of work. `project.yaml` holds `config.description` and an `apps:` list; each app pulls a Helm chart (usually `bjw-s/app-template`) via `repo`/`chart`/`targetRevision`, or deploys a raw git `path`. Companion `values/*.yml` carry per-app Helm values; `manifests/*.yaml` carry raw CRs.
- `Heqetfile` pins the heqet version used by the CMP.
- `values.yaml` holds defaults applied to every generated ArgoCD `Application` (sync policy, pruning, retry).
- `resources/` holds shared inputs: named repos (`repos.yml`), NetworkPolicy groups/rules (`networkpolicy.yml`), and reusable value snippets (`snippets/`).

## Repository layout

| Path | Purpose |
|------|---------|
| `projects/<name>/` | **Central unit.** A group of related apps: `project.yaml`, `values/`, `manifests/`. |
| `Heqetfile` | Pins the heqet version used by the CMP. |
| `values.yaml` | Cluster-wide ArgoCD `Application` defaults. |
| `resources/` | Shared inputs: repos, network policies, value snippets. |
| `ansible/` | Provisions the bare-metal k3s host. |
| `.archive/` | Retired projects, kept for reference (ignored by Renovate). |

## Common tasks

**Add an app** — create `projects/<name>/project.yaml` with an `apps:` entry (e.g. `repo: bjw-s; chart: app-template`) and a matching `values/*.yml`. ArgoCD picks it up on the next sync.

**Upgrade a dependency** — bump `targetRevision` in the relevant `project.yaml` (or let Renovate do it). Validate locally before committing:

```sh
helm template <release> <repo>/<chart> --version <rev> -f projects/<name>/values/<file>.yml
```

For `app-template` charts the repo is `https://bjw-s-labs.github.io/helm-charts`.

**Provision/repair the host** — the `ansible/` playbook sets up k3s (version, registry mirror, CNI/servicelb disabled so Cilium + MetalLB take over).

## Secrets

Secrets are declared, not stored. `secrets:` blocks in `project.yaml` declare the Kubernetes `Secret` + `ExternalSecret` heqet creates; values come from Vault via `vault-secrets-operator`. Never commit secret values.

See [`AGENTS.md`](./AGENTS.md) for guidance intended for automated agents working in this repository.
