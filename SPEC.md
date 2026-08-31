# Spec: Themery — an omarchy theme marketplace

Status: approved in grilling session 2026-08-31. Not yet published to any tracker.

> **Amendments 2026-08-31 (Ryan, post-M7):** publishing is git-repo-only — the
> browser archive upload is removed from the product (the pipeline keeps the
> archive path internally for tests/tooling). Themery checks each theme's
> upstream repo hourly and auto-submits changed versions to the approval queue;
> the catalog marks freshly-updated themes in realtime. Starring no longer
> requires an account (anonymous stars keyed on a hashed address). Themes are
> categorized by palette family and mood, both filterable. Gallery design is a
> hybrid of omarchy.org and the plugin marketplace registry. Catalog is
> populated from the curated omarchy.org extras list.

## Problem Statement

Omarchy users discover themes through a static curated list that links to scattered GitHub repos. There is no way to browse themes visually in one place, no quality or safety gate on what a theme contains, no way to publish a theme without maintaining a GitHub repo, and no feedback loop for authors (no install numbers, no endorsements, no reviews). For theme authors, publishing requires git/GitHub fluency and yields zero insight into whether anyone uses their work.

## Solution

Themery: an independent community marketplace where anyone can browse omarchy themes with beautiful, honest, auto-generated previews; install any theme with the stock `omarchy theme install <url>` command (zero client changes); and publish a theme by simply uploading it — no GitHub required. Every Submission passes mechanical Validation, is Normalized to a "nothing executable" guarantee, and receives human Approval before it becomes installable. Authors get real Install counts (measured from actual git clones), Stars, and Reviews. The site itself is a design statement in the omarchy Quattro aesthetic, and can reskin itself live in any theme's palette ("Try It").

## User Stories

### Browsing & discovery

1. As a visitor, I want to browse a gallery of themes with visually consistent Generated Previews, so that I can compare themes honestly at a glance.
2. As a visitor, I want to sort themes by popularity (stars), installs, and recency, so that I can find well-loved or fresh themes quickly.
3. As a visitor, I want to search themes by name and filter by light/dark, so that I can narrow to what suits my setup.
4. As a visitor, I want a theme detail page with a large mock-desktop preview, palette swatches, version history, reviews, and counts, so that I can evaluate a theme fully before installing.
5. As a visitor, I want a "Try It" mode that reskins the marketplace UI in a theme's palette live, so that I can feel a theme before installing it.
6. As a visitor, I want to view an author's profile with their published themes, so that I can find more work by authors I like.
7. As a visitor, I want the site to respect my light/dark preference with a manual toggle, so that browsing is comfortable.

### Installing

8. As an omarchy user, I want to copy a one-line install command from any theme page, so that installing takes one paste.
9. As an omarchy user, I want `omarchy theme install <themery-url>` to work with the stock client, so that I don't need any new tooling.
10. As an omarchy user, I want `omarchy-theme-update` to pull only approved Versions, so that an unreviewed update never reaches my machine.
11. As an omarchy user, I want a guarantee that marketplace themes contain no executable files, so that installing a stranger's theme is safe.

### Publishing

12. As an author, I want to create an account with email and password, so that I can publish without any third-party identity.
13. As an author, I want to publish a theme by uploading an archive from the browser, so that I never need git or GitHub.
14. As an author, I want to import my existing theme from a git URL, so that my already-published GitHub theme joins the catalog without rework.
15. As an author, I want immediate, specific Validation feedback on upload (missing colors.toml, no backgrounds, oversized, unsafe archive), so that I can fix problems without waiting for a human.
16. As an author, I want to be told exactly which files were stripped at Normalization and why, so that the published artifact never surprises me.
17. As an author, I want to upload a new Version with an optional changelog note, so that installed users receive my improvements via normal updates.
18. As an author, I want a new Submission to replace my still-pending one, so that reviewers never waste time on an obsolete draft.
19. As an author, I want a dashboard showing my themes' pipeline states, install counts, stars, and reviews, so that I can see my work's reach.
20. As an author, I want to see my submission flip to "approved" in real time on my dashboard, so that publishing feels alive.
21. As an author, I want to optionally add real Screenshots to supplement the Generated Preview, so that I can show my theme in authentic use.
22. As a first-time author, I want a "create a theme" guide on the site, so that I can go from zero to published without leaving.

### Social

23. As a signed-in user, I want to Star a theme, so that I can endorse it and bookmark it in one gesture.
24. As a signed-in user, I want a "starred themes" page, so that I can return to themes I've saved.
25. As a signed-in user, I want to write one short text Review per theme, so that I can share my experience without score drama.
26. As a visitor, I want install and star counts on every theme, so that popularity signals are visible without an account.
27. As anyone, I want a pasted theme link to unfurl with a gorgeous generated OG card, so that sharing in Discord/X looks great with zero effort.
28. As a visitor on a busy theme page, I want star/install counters that update live, so that the site feels inhabited.
29. As a visitor, I want a quiet recent-activity pulse on the homepage, so that I can see the catalog is alive.

### Administration

30. As the admin, I want an approval queue that updates in real time, so that I never refresh to see new submissions.
31. As the admin, I want a per-Version review screen showing changed files and old/new backgrounds side by side, so that editorial review takes ~30 seconds.
32. As the admin, I want to approve or reject with an optional note to the author, so that rejection teaches rather than stonewalls.
33. As the admin, I want mechanical Validation and Normalization done before anything reaches my queue, so that I only ever judge content, not safety.
34. As the admin, I want rejected Submissions and their reasons retained, so that repeat-offender patterns are visible.

## Implementation Decisions

- **Positioning:** independent community marketplace; not official; stock-client compatibility is a permanent contract (ADR 0001).
- **Distribution — hosted git (ADR 0001):** the app maintains one bare git repo per Theme on persistent storage. Approving a Version commits + tags it on `main`. Repos are served read-only over HTTP using git's dumb protocol (static files after `update-server-info`), so no git server software. Clones and pulls are counted server-side as Installs and Updates.
- **Publish pipeline (the domain core):** two entry paths (archive upload, git-URL import) converge into one pipeline: *Validation* (parseable `colors.toml`, ≥1 real background image, archive safety — no symlinks/traversal, valid available name, ≤50MB) → *Normalization* (strip `*.lua`, `alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`, `vscode.json`; record what was stripped; ADR 0002) → *Approval* (human, editorial only).
- **Version model:** auto-incremented integers per Theme with optional changelog note; no semver. States: pending → approved | rejected. At most one pending Version per Theme; a new Submission replaces the pending one.
- **Identity:** Rails 8 built-in authentication generator (email/password, bcrypt, reset). Email verification required before first upload. Admin is a boolean on User. One User model; "author" is a relationship (user who owns themes), not a type.
- **Social primitives:** Star (binary, per user per theme), Review (short text, one per user per theme, no numeric score), Install count (from clone telemetry). No likes, comments, follows, or presence.
- **Previews:** canonical previews are rendered from parsed `colors.toml` as a mock omarchy desktop (terminal session, bar, editor buffer, over the theme's real background) via CSS custom properties. The same renderer, via SVG → PNG (libvips), produces catalog cards and OG images. Author screenshots are optional supplements via ActiveStorage.
- **Realtime:** Turbo Streams over Solid Cable for live star/install counters, the admin queue, author dashboard state flips, and the homepage activity pulse.
- **Stack:** Rails 8, Hotwire (Turbo + Stimulus), SQLite with the Solid trifecta (Queue/Cache/Cable), Propshaft, no Node. Hand-rolled token-based vanilla CSS (no Tailwind); mono-forward typography sourced from omarchy's Quattro assets; site light mode derived from the Sherbet palette; every UI color flows through the token layer so "Try It" mode overrides one style block.
- **Hosting:** Railway, single service, single volume holding SQLite, bare repos, and ActiveStorage disk storage. R2/object storage explicitly deferred. Kamal not used.
- **Naming:** project/app "Themery"; domain TBD (`themery.dev` or `themes.yogan.dev`); app must be domain-agnostic.

## Testing Decisions

- Tests assert external behavior only: what a browser sees, what a git client can clone, what a broadcast delivers — never internal method calls or query counts.
- **Seam 1 — HTTP boundary (primary):** Rails system + request tests for browsing, auth, starring, reviewing, upload flow, admin approval, and OG/preview endpoints. Includes contract tests that run a real `git clone` and `git pull` against the test server to prove stock-client installability, and Turbo Stream broadcast assertions for the realtime features.
- **Seam 2 — publish pipeline boundary (secondary):** fixture-driven tests of archive-in → repo-state-out, carrying the adversarial corpus (traversal, symlinks, oversized, missing/malformed `colors.toml`, denied executables) and the normalization ledger (exactly which files stripped).
- Preview renderer correctness is asserted through seam 1 as golden expectations on rendered custom properties, not by unit-testing the parser.
- Prior art: none in-repo (greenfield); conventions follow standard Rails system/request test idioms.

## Out of Scope

- Plugin (non-theme) hosting of any kind.
- Numeric ratings, threaded comments, follows, notifications, presence indicators.
- GitHub/OAuth sign-in; any client-side changes to omarchy; pitching upstream adoption.
- R2/CDN object storage; multi-region or multi-replica scaling; Kamal.
- Automated visual/AI review of theme content (approval stays human).
- Monetization, teams/orgs, theme collections.

## Further Notes

- The strip list and validation rules mirror `omarchy-theme-set`'s deny list; if upstream omarchy adds a denied file type (e.g. a new terminal template), Themery's Normalization list must follow — worth a periodic check on omarchy releases, not automation, at this scale.
- The Generated Preview mock desktop is the single largest design-effort item and the site's signature; budget real polish time there.
- Founding ADRs: `docs/adr/0001-hosted-git-distribution.md`, `docs/adr/0002-strip-on-publish.md`. Domain glossary: `CONTEXT.md`.
