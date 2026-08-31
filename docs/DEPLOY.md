# Deploying Themery to Railway

Single service, single volume. The app is domain-agnostic — no hostname is
baked in anywhere; clone URLs derive from the request.

## Service setup

1. New Railway service from this repo. It builds with the Dockerfile
   (git, libvips, librsvg2-bin, and JetBrains Mono are baked in — all four
   are load-bearing: repos, image variants, OG cards).
2. Attach a **volume** mounted at `/data`.
3. Variables:

   | Variable | Value | Why |
   |---|---|---|
   | `RAILS_MASTER_KEY` | from `config/master.key` | credentials |
   | `DATA_ROOT` | `/data` | all four SQLite DBs, bare git repos, Active Storage |
   | `SOLID_QUEUE_IN_PUMA` | `1` | **without this the publish pipeline enqueues jobs that silently never run** — nothing sets it outside Kamal |
   | `RAILS_MAX_THREADS` | `8` | git pack transfers hold a thread for their duration |

4. Healthcheck path: `/up`.
5. Pre-deploy (release) command: `bin/rails db:prepare` — prepares all four
   databases (primary + cache/queue/cable migration paths).

## After first deploy

- Create your account through the site, verify email, then flag it admin:
  `bin/rails runner 'User.find_by(username: "you").update!(admin: true)'`
  (Railway shell). Admin is a DB bit on User; there is no UI for granting it.
- Smoke-check the queue actually runs: upload a theme; if the submission
  stays "received" forever, `SOLID_QUEUE_IN_PUMA` isn't set.
- Verify a stock install end-to-end:
  `omarchy-theme-install https://<host>/<some-theme>.git`.

## Operational rules

- **Never rewrite history in a hosted repo.** Clients update with plain
  `git pull`; a rewrite bricks every install until reinstall. There is no
  code path that does this — keep it that way.
- **Never run `git gc` / `git repack -a` in a hosted repo.** One pack per
  approved Version is the install/update telemetry. Auto-gc is disabled at
  repo creation; don't re-enable it.
- Mail: `UserMailer` needs an SMTP config in production credentials before
  email verification works for real users (dev uses letter_opener-style
  defaults; production delivery is unconfigured until you set it).
- The strip list in `Publishing::Normalization` mirrors omarchy's
  `INSTALLED_THEME_DENIED` — re-check it against upstream on omarchy
  releases.
