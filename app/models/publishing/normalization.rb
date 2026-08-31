module Publishing
  # Produces the "nothing executable" guarantee (ADR 0002) and the ledger the
  # author sees. Two jobs, in order:
  #
  # 1. Legacy conversion: pre-colors.toml themes carry their palette in
  #    alacritty.toml (the stock client derives colors.toml from it at
  #    install). We do that derivation here, BEFORE the strip — otherwise
  #    every legacy git import would lose its palette and fail Validation.
  #
  # 2. Strip: the client's deny list, applied RECURSIVELY. The client only
  #    checks top-level names when staging, so a backgrounds/evil.lua would
  #    sail through it — our guarantee has to be stronger than the client's
  #    own check. Repository metadata (.git, .gitmodules) goes too.
  #
  # Every action lands in the ledger; the published artifact never surprises
  # the author.
  class Normalization
    Result = Data.define(:ledger)

    # Mirrors INSTALLED_THEME_DENIED in omarchy-theme-set plus the client's
    # blanket *.lua rule. If upstream denies a new file type, add it here.
    DENIED_BASENAMES = %w[alacritty.toml foot.ini ghostty.conf kitty.conf vscode.json].freeze
    DENIED_REASONS = {
      ".lua" => "Lua files are executable code — the omarchy client never stages them",
      "alacritty.toml" => "names the program the terminal launches",
      "foot.ini" => "names the program the terminal launches",
      "ghostty.conf" => "names the program the terminal launches",
      "kitty.conf" => "names the program the terminal launches",
      "vscode.json" => "names a VS Code extension, which is arbitrary JavaScript"
    }.freeze

    def self.apply(root)
      new(Pathname(root)).apply
    end

    def initialize(root)
      @root = root
      @ledger = []
    end

    def apply
      convert_legacy_palette
      strip_repository_metadata
      strip_denied_files
      Result.new(ledger: @ledger)
    end

    private
      def convert_legacy_palette
        return if @root.join("colors.toml").exist?

        alacritty = @root.join("alacritty.toml")
        return unless alacritty.file?

        colors = AlacrittyPalette.derive(alacritty.read)
        return if colors.nil?

        @root.join("colors.toml").write(colors)
        record "colors.toml", action: "generated",
          reason: "derived from alacritty.toml, the way the omarchy client handles pre-colors.toml themes"
      end

      def strip_repository_metadata
        %w[.git .gitmodules].each do |name|
          path = @root.join(name)
          next unless path.exist?

          FileUtils.rm_rf(path)
          record name, action: "stripped", reason: "repository metadata never ships in a theme"
        end
      end

      def strip_denied_files
        @root.find do |path|
          next unless path.file? || path.symlink?

          reason = denial_reason(path.basename.to_s)
          next unless reason

          path.delete
          record path.relative_path_from(@root).to_s, action: "stripped", reason:
        end
      end

      def denial_reason(basename)
        return DENIED_REASONS[".lua"] if basename.end_with?(".lua")
        DENIED_REASONS[basename] if DENIED_BASENAMES.include?(basename)
      end

      def record(file, action:, reason:)
        @ledger << { "file" => file, "action" => action, "reason" => reason }
      end
  end
end
