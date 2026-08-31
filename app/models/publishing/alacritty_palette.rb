module Publishing
  # Derives a colors.toml body from a legacy theme's alacritty.toml, mirroring
  # what omarchy-theme-colors-from-alacritty does for pre-colors.toml themes.
  class AlacrittyPalette
    KEY_MAP = {
      %w[primary background] => "background",
      %w[primary foreground] => "foreground",
      %w[normal red] => "red",
      %w[normal yellow] => "yellow",
      %w[normal green] => "green",
      %w[normal cyan] => "cyan",
      %w[normal blue] => "blue",
      %w[normal magenta] => "magenta",
      %w[bright red] => "bright_red",
      %w[bright yellow] => "bright_yellow",
      %w[bright green] => "bright_green",
      %w[bright cyan] => "bright_cyan",
      %w[bright blue] => "bright_blue",
      %w[bright magenta] => "bright_magenta"
    }.freeze

    # Returns a colors.toml body, or nil when the file yields no usable palette.
    def self.derive(alacritty_toml)
      sections = TomlRB.parse(alacritty_toml).fetch("colors", {})

      pairs = KEY_MAP.filter_map do |(section, key), name|
        value = sections.dig(section, key)
        value = "##{value.delete_prefix('0x')}" if value.is_a?(String) && value.match?(/\A0x\h{6}\z/)
        [ name, value ] if value.is_a?(String) && value.match?(Palette::HEX_COLOR)
      end.to_h

      return nil unless pairs.key?("background") && pairs.key?("foreground")

      pairs.map { |name, value| %(#{name} = "#{value}") }.join("\n") << "\n"
    rescue TomlRB::Error
      nil
    end
  end
end
