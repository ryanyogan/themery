require "test_helper"
require "zip"

# Seam 2: archive in, observable state out. Every assertion here is something
# the author or the admin can see — the Submission's state and error report,
# the pending Version's palette and ledger, and the bytes of the bundle that
# Approval will unpack. Nothing reaches into the pipeline's internals.
module Publishing
  class PipelineTest < ActiveSupport::TestCase
    # --- hostile archives ---------------------------------------------------

    test "a zip whose entry escapes the archive root is refused" do
      submission = process(archive: "traversal.zip")

      assert_predicate submission, :failed?
      assert_error submission, /unsafe path in archive/
      assert_nothing_escaped
    end

    test "a tarball whose entry escapes the archive root is refused" do
      submission = process(archive: "traversal.tar.gz")

      assert_predicate submission, :failed?
      assert_error submission, /unsafe path in archive/
      assert_nothing_escaped
    end

    test "a tarball carrying a symlink is refused" do
      submission = process(archive: "symlink.tar.gz")

      assert_predicate submission, :failed?
      assert_error submission, /links are not allowed/
    end

    # --- invalid themes -----------------------------------------------------

    test "a theme with no colors.toml is refused" do
      %w[no-colors-theme.zip no-colors-theme.tar.gz].each do |archive|
        submission = process(archive:, theme_name: unique_name)

        assert_predicate submission, :failed?, "#{archive} should have failed"
        assert_error submission, /no colors\.toml/
      end
    end

    test "a theme whose colors.toml is malformed is refused" do
      %w[bad-toml-theme.zip bad-toml-theme.tar.gz].each do |archive|
        submission = process(archive:, theme_name: unique_name)

        assert_predicate submission, :failed?, "#{archive} should have failed"
        assert_error submission, /not valid TOML/
      end
    end

    test "a theme with no backgrounds directory is refused" do
      submission = process(archive: "no-bg-theme.tar.gz")

      assert_predicate submission, :failed?
      assert_error submission, /at least one real image in backgrounds/
      assert_error submission, /directory is missing or empty/
    end

    test "a theme whose background is not really an image is refused" do
      submission = process(archive: "fake-bg-theme.zip")

      assert_predicate submission, :failed?
      assert_error submission, /at least one real image in backgrounds/
      assert_error submission, /could not be read as images/
    end

    test "a failed submission creates no theme and no version" do
      themes, versions = Theme.count, Version.count

      process(archive: "traversal.tar.gz")

      assert_equal themes, Theme.count
      assert_equal versions, Version.count
    end

    # --- the happy path -----------------------------------------------------

    test "a good zip becomes a pending version one carrying the parsed palette" do
      submission = process(archive: "good-theme.zip", theme_name: "dawnbreak")
      version = submission.version

      assert_predicate submission, :accepted?
      assert_empty submission.error_report
      assert_equal "dawnbreak", submission.theme.name
      assert_predicate version, :pending?
      assert_equal 1, version.number
      assert_equal "#1e1e2e", version.colors["background"]
      assert_equal "#cdd6f4", version.colors["foreground"]
      assert_equal "#89b4fa", version.colors["accent"]
      assert_equal "dark", version.mode
      assert_predicate version.bundle, :attached?
    end

    test "a good tarball produces the same pending version as the zip" do
      submission = process(archive: "good-theme.tar.gz", theme_name: "duskfall")
      version = submission.version

      assert_predicate submission, :accepted?
      assert_equal 1, version.number
      assert_equal "#1e1e2e", version.colors["background"]
      assert_equal "#cdd6f4", version.colors["foreground"]
      assert_equal "dark", version.mode
      assert_predicate version.bundle, :attached?
    end

    test "the bundle holds the normalized tree the approval will publish" do
      submission = process(archive: "good-theme.tar.gz", theme_name: "tidewrack")

      in_unpacked_bundle(submission.version) do |root|
        assert_path_exists root.join("colors.toml")
        assert_path_exists root.join("backgrounds/1-dawn.png")
      end
    end

    test "the first background is lifted out of the tree for previews" do
      submission = process(archive: "good-theme.tar.gz", theme_name: "kelpforest")

      assert_predicate submission.version.preview_background, :attached?
      assert_equal "1-dawn.png", submission.version.preview_background.filename.to_s
    end

    test "the submission's changelog lands on the version" do
      submission = process(archive: "good-theme.zip", theme_name: "emberwood",
        changelog: "Softer terminal greens.")

      assert_equal "Softer terminal greens.", submission.version.changelog
    end

    # --- normalization ------------------------------------------------------

    test "client-denied files are stripped and every strip is on the ledger" do
      submission = process(archive: "denied-files-theme.zip", theme_name: "saltmarsh")
      ledger = submission.version.normalization_ledger

      assert_predicate submission, :accepted?
      assert_equal %w[alacritty.toml foot.ini ghostty.conf kitty.conf neovim.lua vscode.json].sort,
        ledger.map { |entry| entry["file"] }.sort
      assert_equal [ "stripped" ], ledger.map { |entry| entry["action"] }.uniq
      assert(ledger.all? { |entry| entry["reason"].present? }, "every ledger entry needs a reason")
      assert_match(/Lua/, ledger.find { |entry| entry["file"] == "neovim.lua" }["reason"])
    end

    test "a file that merely looks configurable survives normalization" do
      submission = process(archive: "denied-files-theme.tar.gz", theme_name: "saltflat")

      in_unpacked_bundle(submission.version) do |root|
        assert_path_exists root.join("icons.theme")
        assert_path_exists root.join("colors.toml")
        assert_path_exists root.join("backgrounds/1-dawn.png")
        assert_not root.join("neovim.lua").exist?, "neovim.lua must never reach the bundle"
        assert_not root.join("alacritty.toml").exist?, "alacritty.toml must never reach the bundle"
      end
    end

    test "a legacy theme's palette is derived from alacritty.toml before the strip" do
      submission = process(archive: legacy_archive, theme_name: "oldgrowth")
      version = submission.version
      ledger = version.normalization_ledger

      assert_predicate submission, :accepted?
      assert_equal "generated", ledger.find { |entry| entry["file"] == "colors.toml" }["action"]
      assert_match(/alacritty\.toml/, ledger.find { |entry| entry["file"] == "colors.toml" }["reason"])
      assert_equal "stripped", ledger.find { |entry| entry["file"] == "alacritty.toml" }["action"]

      assert_equal "#1e1e2e", version.colors["background"]
      assert_equal "#cdd6f4", version.colors["foreground"]
      assert_equal "#89b4fa", version.colors["blue"]
      assert_equal "#f9e2af", version.colors["orange"], "orange falls back to yellow"
      assert_equal "dark", version.mode

      in_unpacked_bundle(version) do |root|
        assert_path_exists root.join("colors.toml")
        assert_not root.join("alacritty.toml").exist?
      end
    end

    # --- naming -------------------------------------------------------------

    test "a stock omarchy theme name is refused" do
      submission = process(archive: "good-theme.zip", theme_name: "nord")

      assert_predicate submission, :failed?
      assert_error submission, /stock omarchy theme name/
      assert_nil Theme.find_by(name: "nord")
    end

    test "a name another author already owns is refused" do
      submission = process(archive: "good-theme.zip", theme_name: "aurora", user: users(:admin))

      assert_predicate submission, :failed?
      assert_error submission, /already taken/
      assert_equal users(:one), themes(:aurora).author
    end

    test "an unverified author cannot publish" do
      submission = process(archive: "good-theme.zip", theme_name: "tidewater", user: users(:two))

      assert_predicate submission, :failed?
      assert_error submission, /Verify your email address/
      assert_nil Theme.find_by(name: "tidewater")
    end

    test "the client's name transform decides which theme a submission belongs to" do
      submission = process(archive: "good-theme.zip", theme_name: "omarchy-aurora-theme", user: users(:one))

      assert_predicate submission, :accepted?
      assert_equal themes(:aurora), submission.theme
    end

    # --- resubmission -------------------------------------------------------

    test "a new submission replaces the pending version and keeps the numbering" do
      theme = themes(:aurora)
      superseded = theme.versions.pending.sole
      original = users(:one).submissions.create!(
        kind: "archive_upload", theme_name: theme.name, state: "accepted", theme:, version: superseded
      )

      submission = process(archive: "good-theme.tar.gz", theme_name: "aurora", user: users(:one))

      assert_predicate submission, :accepted?
      assert_not Version.exists?(superseded.id), "the obsolete draft is gone"
      assert_equal 2, submission.version.number
      assert_equal 1, theme.versions.pending.count
      assert_equal [ 1, 2 ], theme.versions.reload.order(:number).pluck(:number)

      assert_predicate original.reload, :accepted?, "the superseded submission survives"
      assert_nil original.version_id
    end

    private
      def process(archive:, theme_name: unique_name, user: users(:one), changelog: nil)
        path = archive.is_a?(Pathname) ? archive : file_fixture("archives/#{archive}")
        submission = user.submissions.create!(kind: "archive_upload", theme_name:, changelog:)
        submission.archive.attach(
          io: path.open("rb"), filename: path.basename.to_s, content_type: "application/octet-stream"
        )
        Pipeline.process(submission)
        submission.reload
      end

      def unique_name = "probe-#{SecureRandom.hex(6)}"

      def assert_error(submission, pattern)
        assert submission.error_report.any? { |message| message.match?(pattern) },
          "expected an error matching #{pattern.inspect}, got #{submission.error_report.inspect}"
      end

      # The traversal corpus aims at the parent of the extraction workspace.
      # Nothing may land there, in the app, or at the filesystem root.
      def assert_nothing_escaped
        [ "/pwned.txt", File.join(Dir.tmpdir, "pwned.txt"),
          Rails.root.join("pwned.txt").to_s, Rails.root.join("tmp/pwned.txt").to_s ].each do |path|
          assert_not File.exist?(path), "#{path} was written by a traversal archive"
        end
      end

      def in_unpacked_bundle(version)
        Dir.mktmpdir("themery-bundle-test") do |dir|
          Release.unpack(version.bundle, Pathname(dir))
          yield Pathname(dir)
        end
      end

      # A pre-colors.toml theme, the shape every legacy GitHub import has: the
      # palette lives in alacritty.toml and the backgrounds are real images.
      def legacy_archive
        dir = Pathname(Dir.mktmpdir("themery-legacy"))
        (dir + "theme/backgrounds").mkpath
        (dir + "theme/alacritty.toml").write(<<~TOML)
          [colors.primary]
          background = "#1e1e2e"
          foreground = "#cdd6f4"

          [colors.normal]
          red = "#f38ba8"
          green = "#a6e3a1"
          yellow = "#f9e2af"
          blue = "#89b4fa"
          magenta = "#f5c2e7"
          cyan = "#94e2d5"
        TOML
        (dir + "theme/backgrounds/1-dawn.png").binwrite(real_png)

        archive = dir + "legacy-theme.tar.gz"
        assert system("tar", "czf", archive.to_s, "-C", (dir + "theme").to_s, ".", out: File::NULL),
          "failed to build the legacy fixture archive"
        archive
      end

      # Borrowed from the good fixture so the background survives Validation's
      # real-image check.
      def real_png
        Zip::File.open(file_fixture("archives/good-theme.zip").to_s) do |zip|
          zip.get_entry("backgrounds/1-dawn.png").get_input_stream.read
        end
      end
  end

  # The pipeline's other entry point. Only the gate is exercised here — what
  # a URL is allowed to be. Cloning itself is a network path and stays out of
  # the suite.
  class GitImportUrlTest < ActiveSupport::TestCase
    test "only https URLs are accepted" do
      [ "http://github.com/ryanyogan/omarchy-aurora-theme",
        "file:///etc/passwd",
        "" ].each do |url|
        assert_equal [ "Import URL must start with https://" ], GitImport.validate_url(url), url.inspect
      end
    end

    test "scp-style and transport-helper URLs are refused" do
      [ "git@github.com:ryanyogan/omarchy-aurora-theme.git", "ext::sh -c whoami" ].each do |url|
        assert_equal [ "Import URL is not a valid URL" ], GitImport.validate_url(url), url.inspect
      end
    end

    test "an https URL with no host is refused" do
      assert_equal [ "Import URL must start with https://" ], GitImport.validate_url("https:///path")
    end

    test "credentials in the URL are refused" do
      assert_equal [ "Import URL cannot carry credentials" ],
        GitImport.validate_url("https://token:x-oauth-basic@github.com/ryanyogan/theme.git")
    end

    test "a host that resolves to a loopback address is refused" do
      assert_equal [ "Import URL resolves to a private address" ],
        GitImport.validate_url("https://localhost/theme.git")
    end

    test "a host that does not resolve is refused" do
      assert_equal [ "Import URL's host could not be resolved" ],
        GitImport.validate_url("https://#{SecureRandom.hex(12)}.invalid/theme.git")
    end
  end
end
