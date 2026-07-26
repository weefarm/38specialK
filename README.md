# 38specialK

Reduce wasted keystrokes interacting with Kubernetes.

`kclo o` instead of `kubectl get pods -n cloudflare -o wide`.

`kclo rf deployment cloudflared-dex` instead of the finalizer patch incantation.

## What it does

38specialK generates short shell functions (`kclo`, `ksys`, `kcnpg`, ...) that
each map to a Kubernetes namespace and dispatch to `kubectl` with the right
`-n` flag. On top of plain pass-through, three verbs get first-class support:

| Verb | Meaning |
|------|---------|
| `o`  | `-o wide` (or custom `-o` format if more args follow) |
| `gf` | list resources with finalizers set in the namespace |
| `rf` | strip finalizers from a resource so it can finish deleting |

Anything else is passed straight to `kubectl -n <ns>`, so `kclo delete pod foo`
and `kclo get deploy` work exactly as you'd expect.

## Prerequisites

- **A Kubernetes cluster** you can reach. 38specialK constructs the full
  `kubectl` commands corresponding to what you give it via the `k<slug>`
  shorthand form, then runs them. Whatever cluster your `kubectl` points at
  is the one the slugs hit.
- **`kubectl` on `$PATH`, working without `sudo`.** The generated functions
  call `kubectl` directly. If your `kubectl` requires `sudo` (e.g.
  `sudo kubectl` on microk8s without the microk8s.kubectl alias), either fix
  that (e.g. `sudo usermod -aG microk8s $USER` and re-login, or add
  `alias kubectl='sudo kubectl'` to your `~/.bashrc`) or use the bash
  reference (`bash/sk.sh`) which you can edit to prefix `sudo` where needed.
- **Linux.** Tested on Ubuntu 26.04 LTS. The Go binary itself is cross-compilable, but
  the generated shell functions assume bash and the `complete` builtin, which
  is Linux/WSL territory. macOS *might* work with `bash-completion` installed
  (bash 3.2 ships with macOS and lacks `_init_completion`; the completion
  block degrades gracefully but won't be as smart). Not tested on macOS thus far, but it probably will be eventually.
- **bash** for the generated shell functions. zsh is not supported by the
  generated snippet (the `complete` builtin is bash-specific); if you're on
  zsh, use the Go binary directly via `skd <slug>` instead of the `k<slug>`
  functions.
- **Go 1.25+** if building from source (only needed for the Go binary; the
  bash reference has no build step).

## Why "38specialK"?

Because it feels like a Wheel-of-Fortune _Before and After_ puzzle?

- **38 Special** (the band? the handgun cartridge? both? neither? we don't know either...)

- **Special K** (the cereal--most definitely the cereal).

- **The default 3-8 character length range for slug names** — 3-8 chars is
   the sweet spot: short enough to type fast, long enough to be memorable and
   unique.

  `k` alone is too short to be unambiguous; `kubectl delete replicaset cloudflared-backchannel -n cloudflared-system` is too long
   to type more often than the once I just did. The range is set as 3-8 characters by default, but can be overridden
   (`allowShorter`/`allowLonger`) in the config.

## What's a "slug"?

A **slug** is a namespace alias. The name plays on two things:

- **A solid bullet has gunpowder and a slug.** `kclo` is the bullet; `k` is the gunpowder
  (propellant); `clo` is the slug (projectile that ultimately interacts with the target).

So when you type `kclo`, think: `k` is the powder, `clo` is the slug, and the
whole thing is the bullet you fire toward your cluster to make something happen.

## Two ways to use it:

### 1. Go binary (recommended)

```bash
go install github.com/weefarm/38specialK/cmd/sk@latest
sk init                       # writes ~/.config/sk/slugs.yaml
$EDITOR ~/.config/sk/slugs.yaml   # edit to match your namespaces
sk install >> ~/.bashrc       # emit shell functions + completions + skd alias
source ~/.bashrc
```

The generated functions are thin wrappers that call back into `sk dispatch`:

```bash
kclo(){ sk dispatch clo "$@"; }
ksys(){ sk dispatch sys "$@"; }
alias skd="sk dispatch"  # alternate invocation: skd clo == kclo
```

All the dispatch logic lives in the binary; the shell functions are dumb pipes.
This means tab completion, `--dry-run`, structured output, and tests come for
free, and there's no multi-line noise copy-pasted into every function to clutter
your .profile or .bashrc.

### 2. Bash reference (no compilation)

```bash
source bash/sk.sh             # from this repo
```
`bash/sk.sh` is the v0 prototype the Go binary replaces. It works without
compiling anything — just source it from your shell or as in include in your
`~/.bashrc`. 

Edit the `add_k8s_slug` lines at the bottom to assign slugs to your namespaces.

## Config file

`~/.config/sk/slugs.yaml` (or `$XDG_CONFIG_HOME/sk/slugs.yaml`):

```yaml
slugs:
  clo: cloudflare
  sys: kube-system
  cnpg: cnpg

filtered:                       # grep-filtered pod listings (kcil/kenv style)
  cil:
    ns: kube-system
    grep: cilium

allSlug: all                   # the all-namespaces slug name; provides "kall" by default.  if you changed it to "any" then "kany" would correspond to "kubectl get pods --all-namespaces"

allowShorter: true              # allow 1-2 char slugs (default: min 3)
# allowLonger: true             # allow 9+ char slugs (default: max 8)
```

Override the config path with `--config PATH` on any `sk` subcommand.

## Verbs in detail

### `o` — output format

```
kclo            # kubectl get pods -n cloudflare
kclo o          # kubectl get pods -n cloudflare -o wide
kclo o yaml     # kubectl get pods -n cloudflare -o yaml
```

### `gf` — get finalizers

Lists every resource in the namespace that has `metadata.finalizers` set.
Output: `Kind/name\t[finalizers...]`.

```
kclo gf         # scan cloudflare namespace for finalizers
kall gf         # whole-cluster scan (all namespaces + cluster-scoped)
gf              # prints usage (footgun guard — too easy to fire by accident)
```

The scan covers a curated type list: pods, deployments, statefulsets,
daemonsets, replicasets, persistentvolumeclaims, services, ingress,
configmaps, secrets (namespaced) and namespaces, persistentvolumes
(cluster-scoped). `ingress` is included deliberately — on clusters using
Cilium Gateway API in place of a conventional ingress controller, scanning
for finalizers on ingress objects catches cases where an AI agent (or a
distracted human) has added an ingress-type object that the Gateway API
controller doesn't reconcile, leaving it stuck terminating.

### `rf` — remove finalizers

Patches `metadata.finalizers` to `null` so a stuck resource can finish
terminating. NOT filtered even on filtered slugs — patching is a deliberate
act and grep would obscure the target.

```
kclo rf deployment foo           # patch deployment/foo in cloudflare
kclo rf deployment foo bar       # patch multiple
kclo rf deployment/foo           # type/name single-arg form
```

`kall rf` is intentionally unsupported — patching across namespaces is too
easy to misfire. Use a namespace-scoped slug instead.

## Alternate invocation: `skd`

`sk install` also emits `alias skd="sk dispatch"`, so you can do:

```
skd clo            # == kclo  == sk dispatch clo
skd clo o          # == kclo o
skd clo rf deployment foo
```

Useful if you prefer an explicit command form over the generated `k<slug>`
functions, or in contexts where the functions aren't loaded (e.g. scripts
that just call `sk` directly).

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
