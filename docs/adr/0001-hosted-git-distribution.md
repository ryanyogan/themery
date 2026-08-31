# Themes are distributed as git repos hosted by Themery itself

The stock omarchy client installs themes with `git clone` and updates them with `git pull` — that contract is not ours to change. Rather than cataloging links to authors' GitHub repos (discovery-only, fails the "publish without GitHub" goal) or serving tarballs (breaks the stock client), Themery maintains one bare git repo per Theme on its own storage: approving a Version commits and tags it on `main`, and repos are served read-only over git's dumb HTTP protocol (static files after `update-server-info`, no git server software).

## Consequences

- Approval gates distribution: an unapproved Version is unreachable by any git client, and `omarchy-theme-update` only ever pulls approved work.
- Installs and Updates are measurable server-side from clone/pull traffic — a metric GitHub-hosted themes cannot have.
- The hosted repo is a build artifact of the pipeline, not the author's working repo; git-URL imports are copied through the same Validation/Normalization as uploads.
- The app is stateful: repos live on the persistent volume alongside SQLite, which ties us to single-instance deployment until that changes.
