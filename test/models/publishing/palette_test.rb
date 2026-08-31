require "test_helper"

# The palette parser's contract, stated against the only corpus that matters:
# the 22 themes the stock omarchy client ships. Those live outside the repo, so
# the corpus tests skip where they are absent (CI) and the invariants that hold
# for any colors.toml are asserted unconditionally below them.
module Publishing
  class PaletteTest < ActiveSupport::TestCase
    VENDORED_THEMES = Pathname(ENV.fetch("XDG_DATA_HOME") { File.join(Dir.home, ".local/share") })
      .join("omarchy/themes")

    # --- the vendored corpus ------------------------------------------------

    test "every vendored omarchy theme parses into a usable palette" do
      files = vendored_colors_files

      assert_operator files.length, :>=, 20, "expected the full vendored theme set"
      files.each do |file|
        name = file.parent.basename.to_s
        result = Palette.parse(file.read)

        assert_predicate result, :ok?, "#{name}: #{result.error}"
        assert_match Palette::HEX_COLOR, result.colors["background"], "#{name} background"
        assert_match Palette::HEX_COLOR, result.colors["foreground"], "#{name} foreground"
        assert_includes %w[light dark], result.mode, "#{name} mode"
      end
    end

    test "every key the preview renderer relies on resolves for every vendored theme" do
      vendored_colors_files.each do |file|
        name = file.parent.basename.to_s
        colors = Palette.parse(file.read).colors

        Palette::FALLBACKS.each_key do |key|
          assert_match Palette::HEX_COLOR, colors[key].to_s, "#{name} has no usable #{key}"
        end
      end
    end

    test "last-horizon, which ships no orange or brown, borrows them" do
      file = vendored_colors_files.find { |path| path.parent.basename.to_s == "last-horizon" }

      skip "last-horizon is not installed" if file.nil?

      source = file.read

      assert_no_match(/^orange\s*=/, source, "fixture drifted: last-horizon now ships an orange")
      assert_no_match(/^brown\s*=/, source, "fixture drifted: last-horizon now ships a brown")

      colors = Palette.parse(source).colors

      assert_equal "#6B5E73", colors["orange"], "orange falls back to yellow"
      assert_equal colors["yellow"], colors["orange"]
      assert_equal colors["orange"], colors["brown"], "brown falls back through orange"
    end

    test "a value that is not a single CSS color is carried but never used as a swatch" do
      file = vendored_colors_files.find { |path| path.parent.basename.to_s == "last-horizon" }

      skip "last-horizon is not installed" if file.nil?

      colors = Palette.parse(file.read).colors

      assert_equal "rgba(8a8588ee) rgba(e2dddcee)", colors["hyprland_active_border"]
      assert_match Palette::HEX_COLOR, colors["accent"]
    end

    # --- mode resolution ----------------------------------------------------

    test "an explicit light mode beats a dark-looking background" do
      result = Palette.parse(<<~TOML)
        mode = "light"
        background = "#101014"
        foreground = "#f2f2f2"
      TOML

      assert_predicate result, :ok?
      assert_equal "light", result.mode
    end

    test "an explicit dark mode beats a light-looking background" do
      result = Palette.parse(<<~TOML)
        mode = "dark"
        background = "#fbf7f0"
        foreground = "#201c18"
      TOML

      assert_equal "dark", result.mode
    end

    test "background luminance decides the mode only when no mode key is present" do
      dark = Palette.parse(%(background = "#1e1e2e"\nforeground = "#cdd6f4"\n))
      light = Palette.parse(%(background = "#fbf7f0"\nforeground = "#201c18"\n))

      assert_equal "dark", dark.mode
      assert_equal "light", light.mode
    end

    test "a mode key that is neither light nor dark falls back to luminance" do
      result = Palette.parse(%(mode = "sepia"\nbackground = "#1e1e2e"\nforeground = "#cdd6f4"\n))

      assert_equal "dark", result.mode
    end

    # --- bad input comes back as a result, never an exception ---------------

    test "malformed TOML yields an error result" do
      result = Palette.parse(%(background = "#1e1e2e\n))

      assert_not_predicate result, :ok?
      assert_match(/not valid TOML/, result.error)
      assert_nil result.colors
      assert_nil result.mode
    end

    test "a colors.toml missing the required keys yields an error result naming them" do
      result = Palette.parse(%(accent = "#89b4fa"\n))

      assert_not_predicate result, :ok?
      assert_match(/background/, result.error)
      assert_match(/foreground/, result.error)
      assert_nil result.colors
    end

    test "a required key that is not a hex color counts as missing" do
      result = Palette.parse(%(background = "rebeccapurple"\nforeground = "#cdd6f4"\n))

      assert_not_predicate result, :ok?
      assert_match(/background/, result.error)
      assert_no_match(/foreground/, result.error)
    end

    test "a required key of the wrong type counts as missing" do
      result = Palette.parse(%(background = 5\nforeground = "#cdd6f4"\n))

      assert_not_predicate result, :ok?
      assert_match(/background/, result.error)
    end

    test "an empty colors.toml yields an error result" do
      result = Palette.parse("")

      assert_not_predicate result, :ok?
      assert_match(/missing required color/, result.error)
    end

    test "eight-digit hex colors are accepted" do
      result = Palette.parse(%(background = "#1e1e2eff"\nforeground = "#cdd6f4ff"\n))

      assert_predicate result, :ok?
      assert_equal "dark", result.mode
    end

    private
      def vendored_colors_files
        skip "vendored omarchy themes are not installed at #{VENDORED_THEMES}" unless VENDORED_THEMES.directory?
        VENDORED_THEMES.glob("*/colors.toml").sort
      end
  end
end
