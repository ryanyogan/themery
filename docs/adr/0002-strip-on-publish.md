# Executable files are stripped from themes at publish, not merely warned about

`omarchy-theme-set` refuses to stage code-carrying files from git-installed themes (all `*.lua`, `alacritty.toml`, `foot.ini`, `ghostty.conf`, `kitty.conf`, `vscode.json`), so shipping them does nothing through the stock install path — but they would still land on disk, waiting for someone to hand-copy them. Normalization deletes these files from the Hosted Repo and tells the author exactly what was dropped and why. This gives Themery a flat guarantee: everything in a marketplace theme is colors and images, nothing executable — which in turn shrinks human Approval to a purely editorial judgment.

## Consequences

- Stock vendored themes ship `neovim.lua`; marketplace themes cannot. Authors may find this surprising, so the stripped-file report must be loud and explanatory.
- The strip list mirrors the client's deny list. If upstream omarchy denies a new file type, Themery's list must follow; check on omarchy releases.
