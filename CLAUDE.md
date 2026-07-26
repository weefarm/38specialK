<!-- faf: faf-git-1785100258922 | Go | library | Reduce wasted keystrokes interacting with Kubernetes. -->
<!-- faf: claim=project.faf | family=FAF -->

# CLAUDE.md — faf-git-1785100258922

## What This Is

Reduce wasted keystrokes interacting with Kubernetes.

## Stack

- **Language:** Go
- **Hosting:** self-hosted Forgejo + GitHub for source; dev environment is self-hosted cluster (Ubuntu 26.04, amd64+arm64, microk8s, microceph)
- **Build:** MANDATORY: before any work, read every file in ~/weefarm/weefarm-prompts/agent-guidelines/ (in filename order) -- binding agent operating rules, canonical source (do not duplicate elsewhere). Windsurf-Next/DevinDesktop-Next, KO (or Go compiler), bash
- **Cicd:** Custom Temporal event-driven (webhook) CI workflows + scheduled safety net workflow runs, ArgoCD

## Context

- **Who:** anyone that interacts with kubectl and would like to do so more effeciently or easily, with less keystrokes. Initially for Nathan, made available publicly.
- **What:** 38specialK generates short shell functions (`kclo`, `ksys`, `kcnpg`, ...) that each map to a Kubernetes namespace and dispatch to `kubectl` with the right `-n` flag. On top of plain pass-through, three verbs get first-class support:
- **Why:** Because it feels like a Wheel-of-Fortune _Before and After_ puzzle?
- **Where:** local cli (written in Go) or bash shell on user's cluster-maintenance or cluster-admin machine
- **When:** July 2026
- **How:** developer + ai agent collaboration to efficiently condense kubectl commands to 3-8 keystroke slugs and automate complex k8s commands with simple invocations

---

*STATUS: BI-SYNC ACTIVE — 2026-07-26T22:19:01.227Z*
