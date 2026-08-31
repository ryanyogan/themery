# Build requirements from architecture red-team (2026-08-31)

Distilled from the pre-implementation steelman review. These are commitments, not suggestions.
Empirical claims below were measured against git 2.55 and the omarchy client scripts.

## Git hosting & telemetry (M2, not M6)

- **Pack-per-Version is the telemetry design.** At repo creation: `git config gc.auto 0` and
  `gc.autoPackLimit 0` (fetch/push can auto-gc behind our back). On approval, in order:
  write objects → update ref → `git repack -d` (incremental, NEVER `-a`) → `update-server-info` last.
  Persist pack→Version mapping in the DB at approval time. Discriminator (measured):
  fresh clone fetches the base pack; updating client fetches only later packs; up-to-date poll
  fetches `info/refs` + `HEAD` only. `git repack -a` would permanently destroy the discriminator.
- **History is append-only forever.** Client updates via plain `git pull`; any rewrite bricks
  installed users until reinstall. No admin action may rewrite `main`. Enforce a *repo* size
  budget (per-upload 50MB cap doesn't bound the 12th version); recompress oversized backgrounds
  during Normalization.
- **Serve `/*.git/*` from a minimal Rack app mounted ahead of session/cookie/CSRF middleware.**
  Bare-body 404s for `objects/info/http-alternates` and `objects/info/alternates` (a 200 there
  redirects git's object lookup). Use `Rack::Files` for correct Content-Length/HEAD/Range.
  Count installs/updates at `GET info/refs?service=git-upload-pack` + subsequent pack fetches.
  Rack::Attack per-IP on the repo prefix.

## Naming (Validation)

- Client derives install dir: `basename $path .git | sed -E 's/^omarchy-//; s/-theme$//' | tr A-Z a-z`.
  Uniqueness must be enforced on the **normalized** name (apply the exact same transform).
- Vendored stock theme names are a hard-reserved blocklist (a marketplace `nord` would *merge into*
  stock nord, inheriting its neovim.lua — `omarchy-theme-set` copies stock first, overlays user theme).

## Archive & import safety (Validation/Normalization)

- Deny list (`*.lua`, alacritty.toml, foot.ini, ghostty.conf, kitty.conf, vscode.json) applies
  **recursively** — the client only checks top level, so `backgrounds/evil.lua` would be staged.
- Reject symlinks at the **git tree** level too (mode 120000), not just archive members.
- Git-URL import: `https` only, refuse `<helper>::`, `GIT_ALLOW_PROTOCOL=https`,
  `--no-recurse-submodules --depth 1 --single-branch`, block private/link-local IPs after DNS
  resolution, wall-clock timeout, disk quota.
- Corpus must also cover: absolute paths, nested `.git/` (gitlink), `.gitmodules`, zip-bomb
  ratios, NFD-vs-NFC unicode names, case-only collisions (`Colors.toml` vs `colors.toml`).
- **Legacy imports:** pre-colors.toml themes derive palette from alacritty.toml (the client does
  this at install). Run alacritty→colors.toml conversion *inside Normalization, before the strip*,
  and report it as a transformation — otherwise every legacy GitHub theme fails Validation.

## Palette parser (surveyed all 22 vendored themes)

- Key counts range 24–28. `orange`/`brown` absent in some themes; no `black`/`white`/`bright_orange`
  keys exist. Values are not all `#rrggbb` (e.g. `hyprland_active_border` is a two-value rgba string).
  Parser must tolerate missing keys with fallbacks and skip non-CSS values.
- Light/dark comes from `mode = "light"|"dark"`; luminance inference is fallback-only.

## Realtime (M4)

- Broadcast only user-agnostic fragments (count nodes); "starred by me" state comes from the
  form response, never a broadcast (jobs have no request context).
- Install/update counters aggregate on a periodic job (10–30s), never per-clone broadcast
  (Solid Cable is poll-backed; each broadcast is a DB insert).
- `broadcasts_refreshes` debounces 500ms/stream — prefer refresh+morph for list/count shapes.
- Try It's injected `<style>` block must be `data-turbo-permanent` or morphing reverts it.

## Ops (Railway)

- `SOLID_QUEUE_IN_PUMA=1` must be set explicitly as a Railway variable (nothing sets it outside
  Kamal); without it the pipeline enqueues jobs that silently never run. Add a smoke check.
- All four SQLite DBs + bare repos + ActiveStorage disk under the mounted volume path.
  Release command runs `db:prepare` covering all four schemas.
- Dockerfile needs `libvips`; `config.active_storage.variant_processor = :vips`; cap input
  image dimensions (analyze parses attacker-supplied images).
- Preview derivatives (card-size backgrounds) are generated at approval time, not on demand.

## Milestones (revised order)

- M0 ✅ dumb-protocol spike (done pre-scaffold: clone+pull over static files verified; request
  log confirmed `info/refs` as the counting point and loose-object storm → repack need).
- M1 scaffold + auth (generator gives Session/Current/password reset but NO sign-up, NO email
  verification — build those: `generates_token_for :email_confirmation` + `unconfirmed_email`
  column per Rails 8.1 "Sign Up and Settings" guide) + admin boolean + domain models.
- M2 publish pipeline + hosted repos + dumb-HTTP serving + **telemetry** + contract tests.
- M3 browsing UI + preview renderer + token CSS + Try It + libvips/Dockerfile work.
- M4 social + realtime. M5 admin queue. M6 OG cards + polish + UI QA.

## Banned anti-patterns

1. No model callbacks for domain transitions (no `after_commit :publish_to_repo`) — pipeline is
   explicit objects invoked from controllers/jobs.
2. No concerns-as-attic; a concern is a named, tested behavior.
3. No shelled git with interpolated strings — argv arrays, explicit chdir, scrubbed env.
4. No exceptions as control flow in Validation/Normalization — typed results carrying the ledger.
5. No `default_scope`; "only approved is cloneable" is an explicit join where repos are served.
6. No callback-maintained counter columns — one explicit recompute path.
