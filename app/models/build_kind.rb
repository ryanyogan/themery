# Classifies how much a theme ships, from its normalized manifest. Purely
# mechanical — no taste involved — so it's recomputed on every accepted
# version and never admin-overridden.
#
#   custom   — deep hand-tuned work: two or more app-level extras
#              (btop/chromium/helix/shell configs, custom CSS, lock art)
#   rounded  — a rounded-out package: one such extra, or several wallpapers
#              plus vendored preview screenshots
#   standard — the essentials: colors.toml and backgrounds
#
# (icons.theme deliberately counts for nothing — every theme ships that
# one-liner, so it discriminates nothing.)
class BuildKind
  KINDS = %w[standard rounded custom].freeze

  CUSTOM_FILES = %w[btop.theme chromium.theme helix.toml shell.toml unlock.png].freeze

  def self.classify(manifest)
    files = manifest.keys.map { |path| path.split("/").last }

    signals = (files & CUSTOM_FILES).size
    signals += 1 if files.any? { |name| name.end_with?(".css") }
    return "custom" if signals >= 2

    backgrounds = manifest.keys.count { |path| path.start_with?("backgrounds/") }
    previews = files.count { |name| name.match?(/\Apreview.*\.(png|jpe?g|webp)\z/i) }
    return "rounded" if signals == 1 || (backgrounds >= 2 && previews >= 1)

    "standard"
  end
end
