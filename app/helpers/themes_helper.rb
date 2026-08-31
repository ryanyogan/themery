module ThemesHelper
  HEX = /\A#\h{6}(\h{2})?\z/

  # The palette as CSS custom properties for the preview renderer. Only
  # hex-shaped values are emitted — colors.toml can legally carry non-CSS
  # strings (hyprland_active_border), and nothing user-authored may reach a
  # style attribute unfiltered.
  def preview_style(colors)
    colors.filter_map { |key, value|
      "--p-#{key.tr('_', '-')}: #{value};" if key.match?(/\A[a-z_]+\z/) && value.to_s.match?(HEX)
    }.join(" ")
  end

  # Try It mode: the site's own token layer, overridden from a theme's
  # palette. One style block, because every UI color flows through tokens.
  def try_it_style(colors)
    mapping = {
      "bg" => colors["background"],
      "surface" => colors["dark_background"],
      "surface-2" => colors["darker_background"],
      "raised" => colors["lighter_background"],
      "ink" => colors["foreground"],
      "ink-dim" => colors["light_foreground"],
      "muted" => colors["muted"],
      "accent" => colors["accent"],
      "selection" => colors["selection"],
      "ok" => colors["green"],
      "warn" => colors["yellow"],
      "err" => colors["red"]
    }
    lines = mapping.filter_map { |token, value| "  --t-#{token}: #{value};" if value.to_s.match?(HEX) }
    ":root, :root[data-theme] {\n#{lines.join("\n")}\n  color-scheme: #{colors['mode'] == 'light' ? 'light' : 'dark'};\n}"
  end

  # Gallery filter links: change one facet, keep the rest.
  def catalog_path(overrides = {})
    themes_path({ sort: @sort, mode: @mode, category: @category, mood: @mood, q: @query }
      .merge(overrides).compact_blank)
  end

  def trying_theme
    return nil unless session[:trying_theme]
    @trying_theme ||= Theme.published.includes(:latest_version).find_by(name: session[:trying_theme])
  end

  def install_command(theme)
    "omarchy theme install #{clone_url(theme)}"
  end

  def clone_url(theme)
    "#{request.base_url}/#{theme.name}.git"
  end

  def preview_background_url(version, variant)
    return nil unless version&.preview_background&.attached?
    url_for(version.preview_background.variant(variant))
  end
end
