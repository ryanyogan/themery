module Publishing
  # Parses a theme's colors.toml into the palette the preview renderer and
  # Try It mode consume. Tolerant by design: across the 22 vendored omarchy
  # themes key counts range 24-28, some omit orange/brown, and some values
  # (hyprland_active_border) aren't single CSS colors — so unknown keys pass
  # through, non-color values are kept but never treated as swatches, and
  # mode falls back to background luminance only when the mode key is absent.
  class Palette
    Result = Data.define(:colors, :mode, :error) do
      def ok? = error.nil?
    end

    HEX_COLOR = /\A#\h{6}(\h{2})?\z/

    # The keys the mock-desktop renderer relies on, with their fallback chain.
    FALLBACKS = {
      "accent" => %w[blue foreground],
      "selection" => %w[lighter_background background],
      "muted" => %w[dark_foreground foreground],
      "dark_background" => %w[background],
      "darker_background" => %w[dark_background background],
      "lighter_background" => %w[selection background],
      "dark_foreground" => %w[muted foreground],
      "light_foreground" => %w[foreground],
      "bright_foreground" => %w[foreground],
      "orange" => %w[yellow red],
      "brown" => %w[orange red],
      "cyan" => %w[blue],
      "magenta" => %w[red]
    }.freeze

    REQUIRED = %w[background foreground].freeze

    # The ANSI dialect some themes speak (and the client's own template
    # placeholders use): color1 is red, color2 green… 9-14 the brights.
    ANSI_ALIASES = {
      "red" => "color1", "green" => "color2", "yellow" => "color3",
      "blue" => "color4", "magenta" => "color5", "cyan" => "color6",
      "bright_red" => "color9", "bright_green" => "color10",
      "bright_yellow" => "color11", "bright_blue" => "color12",
      "bright_magenta" => "color13", "bright_cyan" => "color14"
    }.freeze

    def self.parse(toml_text)
      data = TomlRB.parse(toml_text)
      colors = data.select { |_k, v| v.is_a?(String) }

      ANSI_ALIASES.each do |name, ansi|
        colors[name] = colors[ansi] if !colors[name]&.match?(HEX_COLOR) && colors[ansi]&.match?(HEX_COLOR)
      end

      missing = REQUIRED.reject { |key| colors[key]&.match?(HEX_COLOR) }
      if missing.any?
        return Result.new(colors: nil, mode: nil, error: "colors.toml is missing required color(s): #{missing.join(', ')}")
      end

      FALLBACKS.each do |key, chain|
        next if colors[key]&.match?(HEX_COLOR)
        source = chain.find { |candidate| colors[candidate]&.match?(HEX_COLOR) }
        colors[key] = colors[source] if source
      end

      Result.new(colors:, mode: resolve_mode(colors), error: nil)
    rescue TomlRB::Error => e
      Result.new(colors: nil, mode: nil, error: "colors.toml is not valid TOML: #{e.message.lines.first&.strip}")
    end

    def self.resolve_mode(colors)
      return colors["mode"] if %w[light dark].include?(colors["mode"])

      r, g, b = colors["background"].delete_prefix("#").scan(/\h\h/).first(3).map(&:hex)
      (0.299 * r + 0.587 * g + 0.114 * b) > 128 ? "light" : "dark"
    end
  end
end
