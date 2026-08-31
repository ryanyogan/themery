# Themery

An independent community marketplace for omarchy themes. Anyone can browse themes with generated previews and install them with the stock omarchy client; authors publish by uploading, without needing GitHub.

## Language

### Catalog

**Theme**:
A named, published entry in the catalog: colors and images that reskin an omarchy desktop. Owned by one User.
_Avoid_: Plugin, package, skin

**Version**:
One approved-or-pending revision of a Theme, numbered sequentially (v1, v2, …) with an optional changelog note.
_Avoid_: Release, revision, semver terms

**Author**:
A User in their relationship to a Theme they own. Not a user type — any User becomes an author by publishing.
_Avoid_: Creator, maintainer, publisher (as a role)

**Hosted Repo**:
The bare git repository Themery maintains for a Theme; its `main` always points at the latest approved Version. The thing the stock client clones and pulls.
_Avoid_: Mirror, upstream

### Publishing pipeline

**Submission**:
An archive upload or git-URL import entering the pipeline. At most one pending Submission per Theme; a new one replaces it.
_Avoid_: Upload (as a noun for the domain object), draft

**Validation**:
The mechanical, automatic hard-fail checks on a Submission: parseable colors.toml, at least one real background image, safe archive, valid available name, size cap.
_Avoid_: Linting, verification

**Normalization**:
The automatic step that strips client-denied executable files from a Submission and records what was stripped. Produces the "nothing executable" guarantee.
_Avoid_: Sanitization, cleaning

**Approval**:
The human, editorial-only judgment on a pending Version: content appropriateness, name squatting, quality. Never a safety review — Validation and Normalization own safety.
_Avoid_: Moderation, verification

**Pending / Approved / Rejected**:
The three states of a Version. Only Approved Versions are reachable by any git client.

### Social

**Star**:
The single endorsement primitive: binary, per User per Theme. Doubles as a bookmark.
_Avoid_: Like, favorite, upvote

**Review**:
Short text, one per User per Theme, no numeric score.
_Avoid_: Rating, comment

**Install**:
A counted git clone of a Hosted Repo. The primary reach metric.
_Avoid_: Download

**Update**:
A counted git pull of a Hosted Repo, tracked separately from Installs.

### Presentation

**Generated Preview**:
The canonical visual for a Theme: a mock omarchy desktop rendered from the Theme's parsed colors over its real background. Same renderer produces catalog cards, the theme-page hero, and OG share cards.
_Avoid_: Screenshot (that word means author-supplied images only)

**Screenshot**:
An optional author-supplied real image, supplementary to the Generated Preview.

**Try It**:
The mode where the marketplace UI reskins itself live in a Theme's palette.
