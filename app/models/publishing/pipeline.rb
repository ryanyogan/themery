require "rubygems/package"
require "zlib"

module Publishing
  # The one path every Submission takes, whatever its entry point: a tree on
  # disk goes through Normalization then Validation, the Theme is claimed or
  # matched under the client's canonical name, and a pending Version is
  # created carrying the parsed palette, the ledger, and the normalized tree
  # (as an attached bundle — nothing touches the Hosted Repo until Approval).
  # A still-pending Version for the same Theme is replaced, so reviewers
  # never see an obsolete draft.
  #
  # No exceptions for control flow: authors' mistakes come back as the
  # error report on the Submission, which is the product, not a failure mode.
  class Pipeline
    def self.process(submission)
      new(submission).process
    end

    MAX_ARCHIVE_BYTES = 50.megabytes

    def initialize(submission)
      @submission = submission
      @errors = []
    end

    def process
      unless @submission.user.verified?
        @errors << "Verify your email address before publishing"
        return fail!
      end

      Dir.mktmpdir("themery-submission") do |workspace|
        root = Pathname(workspace)
        stage_tree(root)
        return fail! if @errors.any?

        normalization = Normalization.apply(root)
        validation = Validation.check(root)
        @errors.concat(validation.errors)

        theme = resolve_theme
        return fail! if @errors.any?

        accept!(theme, root, normalization, validation)
      end
    end

    private
      def stage_tree(root)
        case @submission.kind
        when "archive_upload" then stage_archive(root)
        when "git_import" then stage_clone(root)
        end
      end

      def stage_archive(root)
        unless @submission.archive.attached?
          @errors << "No archive was uploaded"
          return
        end
        if @submission.archive.blob.byte_size > MAX_ARCHIVE_BYTES
          @errors << "Archive is larger than the #{MAX_ARCHIVE_BYTES / 1.megabyte}MB limit"
          return
        end

        @submission.archive.open do |file|
          result = Extraction.extract(file.path, into: root)
          @errors.concat(result.errors)
        end
      end

      def stage_clone(root)
        result = GitImport.fetch(@submission.source_url, into: root)
        @errors.concat(result.errors)
        @upstream_commit = result.commit
      end

      def resolve_theme
        name = Theme.canonicalize_name(@submission.theme_name)
        theme = Theme.find_by(name:) || @submission.user.themes.build(name: @submission.theme_name)

        if theme.persisted? && theme.user_id != @submission.user_id
          @errors << "The name \"#{name}\" is already taken"
          return nil
        end
        unless theme.valid?
          @errors.concat(theme.errors.full_messages.map { |message| "Theme name #{name.inspect}: #{message.sub(/\AName /, '')}" })
          return nil
        end
        theme
      end

      def fail!
        @submission.update!(state: "failed", error_report: @errors.uniq)
        @submission
      end

      def accept!(theme, root, normalization, validation)
        palette = validation.palette

        # An upstream sync (or re-import) whose content matches what's
        # already published is nothing to review — record that and stop,
        # but still remember the upstream commit so the hourly check quiets.
        current = theme.persisted? && theme.latest_approved_version
        if current && current.manifest == manifest_of(root) && current.colors == palette.colors
          theme.update!(upstream_commit: @upstream_commit) if @submission.git_import? && @upstream_commit
          @submission.update!(state: "skipped", theme:,
            error_report: [ "Upstream matches the published version — nothing new to submit" ])
          return @submission
        end

        ApplicationRecord.transaction do
          theme.save!
          theme.pending_version&.destroy!

          version = theme.versions.create!(
            number: Version.next_number_for(theme),
            changelog: @submission.changelog,
            colors: palette.colors,
            mode: palette.mode,
            normalization_ledger: normalization.ledger,
            manifest: manifest_of(root)
          )
          version.bundle.attach(
            io: StringIO.new(bundle_tree(root)),
            filename: "#{theme.name}-v#{version.number}.tar.gz",
            content_type: "application/gzip"
          )
          if (background = validation.backgrounds.first)
            version.preview_background.attach(
              io: File.open(background), filename: background.basename.to_s
            )
          end
          validation.backgrounds.each do |image|
            version.backgrounds.attach(io: File.open(image), filename: image.basename.to_s)
          end
          validation.screenshots.each do |image|
            version.screenshots.attach(io: File.open(image), filename: image.basename.to_s)
          end

          if @submission.git_import?
            theme.update!(source_url: @submission.source_url, upstream_commit: @upstream_commit)
          end
          theme.update!(build_kind: BuildKind.classify(version.manifest))
          if theme.category.blank? || theme.mood.blank?
            taxonomy = PaletteTaxonomy.classify(palette.colors, palette.mode)
            theme.update!(
              category: theme.category.presence || taxonomy.category,
              mood: theme.mood.presence || taxonomy.mood
            )
          end
          theme.update!(mode: theme.latest_approved_version&.mode || palette.mode)
          @submission.update!(state: "accepted", theme:, version:, error_report: [])
        end
        @submission
      end

      def manifest_of(root)
        root.find.select(&:file?).to_h { |path| [ path.relative_path_from(root).to_s, path.size ] }
      end

      # The normalized tree, preserved verbatim between Approval and publish.
      def bundle_tree(root)
        buffer = StringIO.new
        Zlib::GzipWriter.wrap(buffer) do |gz|
          Gem::Package::TarWriter.new(gz) do |tar|
            root.find do |path|
              next unless path.file?
              name = path.relative_path_from(root).to_s
              tar.add_file_simple(name, 0o644, path.size) { |io| io.write(path.binread) }
            end
          end
        end
        buffer.string
      end
  end
end
